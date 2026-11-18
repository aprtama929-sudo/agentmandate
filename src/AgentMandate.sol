// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentRegistry, IAgentIdToken} from "./AgentRegistry.sol";

/// @title AgentMandate — Agent-ID-native scoped payment mandates on BNB Chain
/// @notice A principal who holds an Agent ID deposits BNB or USDT and creates
///         an on-chain *mandate* appointing one registered agent (see
///         AgentRegistry) to make payments under hard, contract-enforced
///         limits:
///
///           - a per-payment cap,
///           - a total budget cap,
///           - an expiry timestamp,
///           - an optional payee allowlist.
///
///         Agent ID is load-bearing at every step, not decorative:
///           1. `createMandate` reverts unless the principal holds an Agent ID;
///           2. the appointed agent must be registered in AgentRegistry
///              (which itself requires holding an Agent ID);
///           3. `pay` re-checks the agent's live eligibility on every call —
///              an agent that deregisters or loses its Agent ID immediately
///              loses the ability to move funds.
///
///         The principal can revoke at any time and reclaim every unspent
///         unit. After expiry anyone can close the mandate, which refunds
///         the principal.
///
/// @dev    Permissions: this contract has NO owner and NO admin functions.
///         The deployer cannot pause, upgrade, redirect, or withdraw user
///         funds. The only addresses that can move a mandate's funds are its
///         principal (fund / revoke) and its appointed agent (pay, within
///         scope). Constructor parameters (Agent ID contract, registry) are
///         immutable. Supported assets are native BNB and BSC USDT only, so
///         mandate accounting can never be spoofed with a look-alike token.

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract AgentMandate {
    // ------------------------------------------------------------------ types

    struct Mandate {
        address principal; // Agent ID holder who created (and funds) the mandate
        address agent; // registered agent allowed to execute payments
        address asset; // address(0) = native BNB, otherwise the USDT contract
        uint256 perTxCap; // max amount per single payment
        uint256 totalBudget; // max cumulative amount over the mandate's life
        uint256 funded; // assets actually deposited into the vault
        uint256 spent; // assets already paid out
        uint64 expiresAt; // unix timestamp; payments after this revert
        bool allowAnyPayee; // if false, payees must be allowlisted
        bool revoked; // once true, the mandate is dead forever
    }

    // -------------------------------------------------------------- constants

    /// @notice BSC USDT (BEP-20), the only ERC-20 asset mandates can use.
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;

    /// @notice Asset identifier for native BNB mandates.
    address public constant NATIVE = address(0);

    // ------------------------------------------------------------------ state

    /// @notice The SPACE ID Agent ID contract (immutable).
    IAgentIdToken public immutable agentIdToken;

    /// @notice The agent registry consulted on create + every payment (immutable).
    AgentRegistry public immutable registry;

    uint256 public mandateCount;
    mapping(uint256 => Mandate) private _mandates;
    mapping(uint256 => mapping(address => bool)) private _payeeAllowed;

    uint256 private _reentrancyLock = 1;

    // ----------------------------------------------------------------- events

    event MandateCreated(
        uint256 indexed id,
        address indexed principal,
        address indexed agent,
        address asset,
        uint256 perTxCap,
        uint256 totalBudget,
        uint64 expiresAt,
        bool allowAnyPayee
    );
    event MandateFunded(uint256 indexed id, address indexed from, uint256 amount, uint256 fundedTotal);
    event PayeeAllowedSet(uint256 indexed id, address indexed payee, bool allowed);
    event PaymentExecuted(
        uint256 indexed id,
        address indexed agent,
        address indexed payee,
        uint256 amount,
        string memo,
        uint256 spentTotal,
        uint256 remainingBudget
    );
    event MandateRevoked(uint256 indexed id, address indexed principal, uint256 refunded);
    event MandateClosedExpired(uint256 indexed id, address indexed principal, uint256 refunded);

    // ----------------------------------------------------------------- errors

    error NotPrincipal(uint256 id);
    error NotAgent(uint256 id);
    error PrincipalNotAgentIdHolder(address account);
    error AgentNotEligible(address agent);
    error MandateRevokedError(uint256 id);
    error MandateExpired(uint256 id);
    error MandateNotExpired(uint256 id);
    error ZeroAddress();
    error InvalidLimits();
    error UnsupportedAsset(address asset);
    error WrongFundMethod(uint256 id);
    error ZeroAmount();
    error OverPerTxCap(uint256 amount, uint256 cap);
    error OverBudget(uint256 amount, uint256 remaining);
    error InsufficientFunds(uint256 amount, uint256 available);
    error PayeeNotAllowed(uint256 id, address payee);
    error TransferFailed();
    error ReentrantCall();

    // -------------------------------------------------------------- modifiers

    modifier nonReentrant() {
        if (_reentrancyLock != 1) revert ReentrantCall();
        _reentrancyLock = 2;
        _;
        _reentrancyLock = 1;
    }

    modifier onlyPrincipal(uint256 id) {
        if (msg.sender != _mandates[id].principal) revert NotPrincipal(id);
        _;
    }

    // ------------------------------------------------------------ constructor

    constructor(address agentIdToken_, address registry_) {
        require(agentIdToken_ != address(0) && registry_ != address(0), "AgentMandate: zero address");
        agentIdToken = IAgentIdToken(agentIdToken_);
        registry = AgentRegistry(registry_);
    }

    // ------------------------------------------------------------ token utils

    /// @dev Handles ERC-20s that return true, return nothing, or return false.
    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) =
            address(token).call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) =
            address(token).call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _payOut(address asset, address to, uint256 amount) internal {
        if (asset == NATIVE) {
            (bool ok,) = to.call{value: amount}("");
            if (!ok) revert TransferFailed();
        } else {
            _safeTransfer(IERC20(asset), to, amount);
        }
    }

    // -------------------------------------------------------------- lifecycle

    /// @notice Create a payment mandate appointing `agent`.
    /// @dev    Gate 1 (Agent ID): the caller must hold an Agent ID.
    ///         Gate 2 (registry): `agent` must be an eligible registered agent.
    ///         Does not move funds; call `fundNative` / `fundToken` next.
    /// @param agent         Registered agent that will execute payments.
    /// @param asset         address(0) for BNB, or the BSC USDT contract.
    /// @param perTxCap      Maximum amount per single payment (> 0).
    /// @param totalBudget   Maximum cumulative spend (> 0, >= perTxCap).
    /// @param expiresAt     Unix timestamp after which payments revert (future).
    /// @param allowAnyPayee If false, payees must be added via `setPayeeAllowed`.
    /// @return id           The new mandate id.
    function createMandate(
        address agent,
        address asset,
        uint256 perTxCap,
        uint256 totalBudget,
        uint64 expiresAt,
        bool allowAnyPayee
    ) external returns (uint256 id) {
        if (agentIdToken.balanceOf(msg.sender) == 0) revert PrincipalNotAgentIdHolder(msg.sender);
        if (agent == address(0)) revert ZeroAddress();
        if (!registry.isEligibleAgent(agent)) revert AgentNotEligible(agent);
        if (asset != NATIVE && asset != USDT) revert UnsupportedAsset(asset);
        if (perTxCap == 0 || totalBudget < perTxCap) revert InvalidLimits();
        if (expiresAt <= block.timestamp) revert InvalidLimits();

        id = ++mandateCount;
        _mandates[id] = Mandate({
            principal: msg.sender,
            agent: agent,
            asset: asset,
            perTxCap: perTxCap,
            totalBudget: totalBudget,
            funded: 0,
            spent: 0,
            expiresAt: expiresAt,
            allowAnyPayee: allowAnyPayee,
            revoked: false
        });

        emit MandateCreated(id, msg.sender, agent, asset, perTxCap, totalBudget, expiresAt, allowAnyPayee);
    }

    /// @notice Deposit native BNB into a BNB mandate (principal only).
    function fundNative(uint256 id) external payable onlyPrincipal(id) nonReentrant {
        Mandate storage m = _mandates[id];
        if (m.revoked) revert MandateRevokedError(id);
        if (m.asset != NATIVE) revert WrongFundMethod(id);
        if (msg.value == 0) revert ZeroAmount();
        m.funded += msg.value;
        emit MandateFunded(id, msg.sender, msg.value, m.funded);
    }

    /// @notice Deposit USDT into a USDT mandate (principal only). The
    ///         principal must `approve` this contract for `amount` first —
    ///         an exact, user-visible approval; this contract never requests
    ///         or uses unlimited approvals on anyone's behalf.
    function fundToken(uint256 id, uint256 amount) external onlyPrincipal(id) nonReentrant {
        Mandate storage m = _mandates[id];
        if (m.revoked) revert MandateRevokedError(id);
        if (m.asset == NATIVE) revert WrongFundMethod(id);
        if (amount == 0) revert ZeroAmount();
        _safeTransferFrom(IERC20(m.asset), msg.sender, address(this), amount);
        m.funded += amount;
        emit MandateFunded(id, msg.sender, amount, m.funded);
    }

    /// @notice Add or remove a payee on the mandate allowlist (principal only).
    ///         Irrelevant when the mandate was created with `allowAnyPayee`.
    function setPayeeAllowed(uint256 id, address payee, bool allowed) external onlyPrincipal(id) {
        if (payee == address(0)) revert ZeroAddress();
        _payeeAllowed[id][payee] = allowed;
        emit PayeeAllowedSet(id, payee, allowed);
    }

    /// @notice Execute a payment. Callable ONLY by the mandate's agent.
    ///         Enforces, in order: caller is the agent, agent is STILL an
    ///         eligible registered Agent ID holder (live registry check),
    ///         not revoked, not expired, per-tx cap, total budget, deposited
    ///         funds, payee allowlist.
    /// @param memo Free-text reference (invoice id, order hash, ...) stored
    ///             permanently in the PaymentExecuted event for auditability.
    function pay(uint256 id, address payee, uint256 amount, string calldata memo) external nonReentrant {
        Mandate storage m = _mandates[id];
        if (msg.sender != m.agent) revert NotAgent(id);
        if (!registry.isEligibleAgent(m.agent)) revert AgentNotEligible(m.agent);
        if (m.revoked) revert MandateRevokedError(id);
        if (block.timestamp > m.expiresAt) revert MandateExpired(id);
        if (payee == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > m.perTxCap) revert OverPerTxCap(amount, m.perTxCap);

        uint256 remainingBudget = m.totalBudget - m.spent;
        if (amount > remainingBudget) revert OverBudget(amount, remainingBudget);

        uint256 available = m.funded - m.spent;
        if (amount > available) revert InsufficientFunds(amount, available);

        if (!m.allowAnyPayee && !_payeeAllowed[id][payee]) revert PayeeNotAllowed(id, payee);

        // effects before interaction
        m.spent += amount;
        _payOut(m.asset, payee, amount);

        emit PaymentExecuted(id, msg.sender, payee, amount, memo, m.spent, m.totalBudget - m.spent);
    }

    /// @notice Instantly revoke a mandate and reclaim all unspent funds.
    ///         Works before or after expiry; the mandate can never pay again.
    function revoke(uint256 id) external onlyPrincipal(id) nonReentrant {
        Mandate storage m = _mandates[id];
        if (m.revoked) revert MandateRevokedError(id);
        m.revoked = true;

        uint256 refund = m.funded - m.spent;
        m.funded = m.spent; // keep accounting exact: nothing left to claim
        if (refund > 0) _payOut(m.asset, m.principal, refund);

        emit MandateRevoked(id, m.principal, refund);
    }

    /// @notice After expiry, anyone may close the mandate; unspent funds are
    ///         returned to the principal. (The principal can also `revoke`.)
    function closeExpired(uint256 id) external nonReentrant {
        Mandate storage m = _mandates[id];
        if (m.revoked) revert MandateRevokedError(id);
        if (block.timestamp <= m.expiresAt) revert MandateNotExpired(id);
        m.revoked = true;

        uint256 refund = m.funded - m.spent;
        m.funded = m.spent;
        if (refund > 0) _payOut(m.asset, m.principal, refund);

        emit MandateClosedExpired(id, m.principal, refund);
    }

    // ------------------------------------------------------------------ views

    function getMandate(uint256 id) external view returns (Mandate memory) {
        return _mandates[id];
    }

    function isPayeeAllowed(uint256 id, address payee) external view returns (bool) {
        Mandate storage m = _mandates[id];
        return m.allowAnyPayee || _payeeAllowed[id][payee];
    }

    /// @notice Spendable amount right now = min(remaining budget, deposited
    ///         funds), or 0 when revoked/expired. What an agent UI polls
    ///         before paying.
    function spendable(uint256 id) external view returns (uint256) {
        Mandate storage m = _mandates[id];
        if (m.revoked || block.timestamp > m.expiresAt) return 0;
        uint256 remainingBudget = m.totalBudget - m.spent;
        uint256 available = m.funded - m.spent;
        return remainingBudget < available ? remainingBudget : available;
    }

    /// @dev Accept plain BNB transfers nowhere: funding must go through
    ///      `fundNative` so mandate accounting stays exact. (No receive /
    ///      fallback is defined, so stray transfers revert.)
}
