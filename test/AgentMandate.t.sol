// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {AgentMandate} from "../src/AgentMandate.sol";
import {MockAgentId, MockERC20} from "./mocks/Mocks.sol";

contract AgentMandateTest is Test {
    MockAgentId internal agentId;
    AgentRegistry internal registry;
    AgentMandate internal vault;
    MockERC20 internal usdt; // etched onto the real BSC USDT address

    address internal principal = makeAddr("principal");
    address internal agent = makeAddr("agent");
    address internal unregistered = makeAddr("unregistered"); // holds ID, never registers
    address internal stranger = makeAddr("stranger"); // no Agent ID
    address internal payee = makeAddr("payee");
    address internal payee2 = makeAddr("payee2");

    uint64 internal expiry;

    function setUp() public {
        agentId = new MockAgentId();
        registry = new AgentRegistry(address(agentId));
        vault = new AgentMandate(address(agentId), address(registry));

        // Etch the mock ERC-20 onto the real USDT address so the vault's
        // hardcoded asset allowlist behaves exactly as on mainnet.
        MockERC20 mock = new MockERC20();
        vm.etch(vault.USDT(), address(mock).code);
        usdt = MockERC20(vault.USDT());

        agentId.setBalance(principal, 1);
        agentId.setBalance(agent, 1);
        agentId.setBalance(unregistered, 1);

        vm.prank(agent);
        registry.registerAgent();

        expiry = uint64(block.timestamp + 7 days);

        vm.deal(principal, 100 ether);
        vm.deal(agent, 1 ether);
        usdt.mint(principal, 1_000_000e18);
    }

    // ------------------------------------------------------------ helpers

    function _createBnbMandate(bool allowAny) internal returns (uint256 id) {
        vm.prank(principal);
        id = vault.createMandate(agent, address(0), 0.4 ether, 1 ether, expiry, allowAny);
    }

    function _fundedBnbMandate(bool allowAny) internal returns (uint256 id) {
        id = _createBnbMandate(allowAny);
        vm.prank(principal);
        vault.fundNative{value: 1 ether}(id);
    }

    // ------------------------------------------------- creation / Agent ID

    function test_CreateRevertsForNonHolderPrincipal() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.PrincipalNotAgentIdHolder.selector, stranger));
        vault.createMandate(agent, address(0), 0.4 ether, 1 ether, expiry, true);
    }

    function test_CreateRevertsForUnregisteredAgent() public {
        vm.prank(principal);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.AgentNotEligible.selector, unregistered));
        vault.createMandate(unregistered, address(0), 0.4 ether, 1 ether, expiry, true);
    }

    function test_CreateRevertsForAgentWithoutId() public {
        vm.prank(principal);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.AgentNotEligible.selector, stranger));
        vault.createMandate(stranger, address(0), 0.4 ether, 1 ether, expiry, true);
    }

    function test_CreateRevertsUnsupportedAsset() public {
        address junk = makeAddr("junkToken");
        vm.prank(principal);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.UnsupportedAsset.selector, junk));
        vault.createMandate(agent, junk, 100, 1000, expiry, true);
    }

    function test_CreateRevertsInvalidLimits() public {
        vm.startPrank(principal);
        vm.expectRevert(AgentMandate.InvalidLimits.selector);
        vault.createMandate(agent, address(0), 0, 1 ether, expiry, true); // zero cap
        vm.expectRevert(AgentMandate.InvalidLimits.selector);
        vault.createMandate(agent, address(0), 2 ether, 1 ether, expiry, true); // budget < cap
        vm.expectRevert(AgentMandate.InvalidLimits.selector);
        vault.createMandate(agent, address(0), 0.4 ether, 1 ether, uint64(block.timestamp), true); // past expiry
        vm.stopPrank();
    }

    function test_CreateStoresMandate() public {
        uint256 id = _createBnbMandate(false);
        AgentMandate.Mandate memory m = vault.getMandate(id);
        assertEq(m.principal, principal);
        assertEq(m.agent, agent);
        assertEq(m.asset, address(0));
        assertEq(m.perTxCap, 0.4 ether);
        assertEq(m.totalBudget, 1 ether);
        assertEq(m.funded, 0);
        assertEq(m.spent, 0);
        assertEq(m.expiresAt, expiry);
        assertFalse(m.allowAnyPayee);
        assertFalse(m.revoked);
        assertEq(vault.mandateCount(), 1);
    }

    // ------------------------------------------------------------- funding

    function test_FundNativeRevertsForNonPrincipal() public {
        uint256 id = _createBnbMandate(true);
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.NotPrincipal.selector, id));
        vault.fundNative{value: 1 ether}(id);
    }

    function test_FundNativeRevertsOnTokenMandate() public {
        address usdtAddr = vault.USDT(); // hoist: argument evaluation would consume the prank
        vm.prank(principal);
        uint256 id = vault.createMandate(agent, usdtAddr, 100e18, 1000e18, expiry, true);
        vm.prank(principal);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.WrongFundMethod.selector, id));
        vault.fundNative{value: 1 ether}(id);
    }

    function test_FundTokenRevertsOnNativeMandate() public {
        uint256 id = _createBnbMandate(true);
        vm.prank(principal);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.WrongFundMethod.selector, id));
        vault.fundToken(id, 100e18);
    }

    // ------------------------------------------------------------- payment

    function test_PayNativeHappyPath() public {
        uint256 id = _fundedBnbMandate(true);
        uint256 payeeBefore = payee.balance;

        vm.prank(agent);
        vault.pay(id, payee, 0.3 ether, "invoice-001");

        assertEq(payee.balance, payeeBefore + 0.3 ether);
        AgentMandate.Mandate memory m = vault.getMandate(id);
        assertEq(m.spent, 0.3 ether);
        assertEq(vault.spendable(id), 0.7 ether);
    }

    function test_PayRevertsForNonAgent() public {
        uint256 id = _fundedBnbMandate(true);
        vm.prank(principal);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.NotAgent.selector, id));
        vault.pay(id, payee, 0.1 ether, "x");
    }

    function test_PayRevertsOverPerTxCap() public {
        uint256 id = _fundedBnbMandate(true);
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.OverPerTxCap.selector, 0.41 ether, 0.4 ether));
        vault.pay(id, payee, 0.41 ether, "x");
    }

    function test_PayRevertsOverBudget() public {
        uint256 id = _fundedBnbMandate(true);
        vm.startPrank(agent);
        vault.pay(id, payee, 0.4 ether, "a");
        vault.pay(id, payee, 0.4 ether, "b");
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.OverBudget.selector, 0.3 ether, 0.2 ether));
        vault.pay(id, payee, 0.3 ether, "c");
        vm.stopPrank();
    }

    function test_PayRevertsOverFunded() public {
        vm.prank(principal);
        uint256 id = vault.createMandate(agent, address(0), 1 ether, 1 ether, expiry, true);
        vm.prank(principal);
        vault.fundNative{value: 0.5 ether}(id);

        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.InsufficientFunds.selector, 0.6 ether, 0.5 ether));
        vault.pay(id, payee, 0.6 ether, "x");
    }

    function test_PayRevertsAfterExpiry() public {
        uint256 id = _fundedBnbMandate(true);
        vm.warp(expiry + 1);
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.MandateExpired.selector, id));
        vault.pay(id, payee, 0.1 ether, "x");
    }

    function test_PayeeAllowlistEnforced() public {
        uint256 id = _fundedBnbMandate(false);

        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.PayeeNotAllowed.selector, id, payee));
        vault.pay(id, payee, 0.1 ether, "x");

        vm.prank(principal);
        vault.setPayeeAllowed(id, payee, true);
        assertTrue(vault.isPayeeAllowed(id, payee));
        assertFalse(vault.isPayeeAllowed(id, payee2));

        vm.prank(agent);
        vault.pay(id, payee, 0.1 ether, "x");
        assertEq(payee.balance, 0.1 ether);
    }

    function test_SetPayeeAllowedRevertsForNonPrincipal() public {
        uint256 id = _fundedBnbMandate(false);
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.NotPrincipal.selector, id));
        vault.setPayeeAllowed(id, payee, true);
    }

    function test_PayRevertsAfterAgentDeregisters() public {
        uint256 id = _fundedBnbMandate(true);
        vm.prank(agent);
        registry.deregisterAgent();

        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.AgentNotEligible.selector, agent));
        vault.pay(id, payee, 0.1 ether, "x");
    }

    function test_PayRevertsIfAgentIdBalanceZeroed() public {
        uint256 id = _fundedBnbMandate(true);
        agentId.setBalance(agent, 0);

        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.AgentNotEligible.selector, agent));
        vault.pay(id, payee, 0.1 ether, "x");
    }

    // ------------------------------------------------------- revoke / close

    function test_RevokeRefundsUnspent() public {
        uint256 id = _fundedBnbMandate(true);
        vm.prank(agent);
        vault.pay(id, payee, 0.3 ether, "a");

        uint256 before = principal.balance;
        vm.prank(principal);
        vault.revoke(id);
        assertEq(principal.balance, before + 0.7 ether);

        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.MandateRevokedError.selector, id));
        vault.pay(id, payee, 0.1 ether, "b");
        assertEq(vault.spendable(id), 0);
    }

    function test_RevokeRevertsForNonPrincipal() public {
        uint256 id = _fundedBnbMandate(true);
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.NotPrincipal.selector, id));
        vault.revoke(id);
    }

    function test_CloseExpiredRefundsPrincipal() public {
        uint256 id = _fundedBnbMandate(true);

        vm.expectRevert(abi.encodeWithSelector(AgentMandate.MandateNotExpired.selector, id));
        vault.closeExpired(id);

        vm.warp(expiry + 1);
        uint256 before = principal.balance;
        vm.prank(stranger); // anyone may close after expiry
        vault.closeExpired(id);
        assertEq(principal.balance, before + 1 ether);
    }

    // ---------------------------------------------------------------- USDT

    function test_UsdtMandateFullFlow() public {
        vm.startPrank(principal);
        uint256 id = vault.createMandate(agent, vault.USDT(), 100e18, 1000e18, expiry, true);
        usdt.approve(address(vault), 500e18);
        vault.fundToken(id, 500e18);
        vm.stopPrank();

        assertEq(usdt.balanceOf(address(vault)), 500e18);
        assertEq(vault.spendable(id), 500e18);

        vm.prank(agent);
        vault.pay(id, payee, 100e18, "usdt-invoice-1");
        assertEq(usdt.balanceOf(payee), 100e18);

        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(AgentMandate.OverPerTxCap.selector, 101e18, 100e18));
        vault.pay(id, payee, 101e18, "too-big");

        uint256 principalBefore = usdt.balanceOf(principal);
        vm.prank(principal);
        vault.revoke(id);
        assertEq(usdt.balanceOf(principal), principalBefore + 400e18);
    }
}
