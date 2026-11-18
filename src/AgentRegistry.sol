// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title AgentRegistry — the Agent ID gate for AgentMandate
/// @notice A public registry of AI agents that hold an Agent ID (the SPACE ID
///         ERC-721 issued to Binance Agentic Wallet users). Holding an Agent ID
///         is the *only* way to register, and registration is the *only* way to
///         be appointed under an AgentMandate payment mandate. Registration is
///         therefore not a cosmetic profile step: AgentMandate reads this
///         registry on mandate creation AND on every payment execution.
///
/// @dev    Permissions: this contract has NO owner and NO admin functions.
///         Nobody — including the deployer — can register, remove, or edit
///         another address's entry. An agent can only register and deregister
///         itself. The Agent ID contract address is immutable.

interface IAgentIdToken {
    function balanceOf(address account) external view returns (uint256);
}

contract AgentRegistry {
    // ------------------------------------------------------------------ state

    /// @notice The SPACE ID Agent ID contract on BNB Chain (immutable).
    IAgentIdToken public immutable agentIdToken;

    mapping(address => bool) private _registered;
    mapping(address => uint256) private _registeredAt;

    /// @notice Total number of currently registered agents.
    uint256 public agentCount;

    // ----------------------------------------------------------------- events

    event AgentRegistered(address indexed agent, uint256 timestamp, uint256 agentCount);
    event AgentDeregistered(address indexed agent, uint256 timestamp, uint256 agentCount);

    // ----------------------------------------------------------------- errors

    error NotAgentIdHolder(address account);
    error AlreadyRegistered(address account);
    error NotRegistered(address account);

    // ------------------------------------------------------------ constructor

    constructor(address agentIdToken_) {
        require(agentIdToken_ != address(0), "AgentRegistry: zero address");
        agentIdToken = IAgentIdToken(agentIdToken_);
    }

    // -------------------------------------------------------------- lifecycle

    /// @notice Register the caller as an agent. The caller MUST hold an
    ///         Agent ID (balanceOf > 0 on the Agent ID contract). One
    ///         registration per address; registering twice reverts.
    function registerAgent() external {
        if (agentIdToken.balanceOf(msg.sender) == 0) revert NotAgentIdHolder(msg.sender);
        if (_registered[msg.sender]) revert AlreadyRegistered(msg.sender);

        _registered[msg.sender] = true;
        _registeredAt[msg.sender] = block.timestamp;
        agentCount += 1;

        emit AgentRegistered(msg.sender, block.timestamp, agentCount);
    }

    /// @notice Remove the caller's own registration. While deregistered, the
    ///         address cannot be appointed to new mandates and cannot execute
    ///         payments under existing ones (AgentMandate checks eligibility
    ///         at execution time). Funds are never at risk: principals can
    ///         always revoke and withdraw their own unspent balance.
    function deregisterAgent() external {
        if (!_registered[msg.sender]) revert NotRegistered(msg.sender);

        _registered[msg.sender] = false;
        _registeredAt[msg.sender] = 0;
        agentCount -= 1;

        emit AgentDeregistered(msg.sender, block.timestamp, agentCount);
    }

    // ------------------------------------------------------------------ views

    /// @notice True if `account` currently holds at least one Agent ID.
    function holdsAgentId(address account) external view returns (bool) {
        return agentIdToken.balanceOf(account) > 0;
    }

    /// @notice True if `account` has registered (and not deregistered).
    function isRegistered(address account) external view returns (bool) {
        return _registered[account];
    }

    /// @notice Registration timestamp of `account` (0 if not registered).
    function registeredAt(address account) external view returns (uint256) {
        return _registeredAt[account];
    }

    /// @notice The full appointment/execution gate used by AgentMandate:
    ///         the address must be registered AND still hold an Agent ID.
    function isEligibleAgent(address account) external view returns (bool) {
        return _registered[account] && agentIdToken.balanceOf(account) > 0;
    }
}
