// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {MockAgentId} from "./mocks/Mocks.sol";

contract AgentRegistryTest is Test {
    MockAgentId internal agentId;
    AgentRegistry internal registry;

    address internal holder = makeAddr("holder");
    address internal holder2 = makeAddr("holder2");
    address internal stranger = makeAddr("stranger");

    function setUp() public {
        agentId = new MockAgentId();
        registry = new AgentRegistry(address(agentId));
        agentId.setBalance(holder, 1);
        agentId.setBalance(holder2, 1);
    }

    function test_RegisterRevertsWithoutAgentId() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry.NotAgentIdHolder.selector, stranger));
        registry.registerAgent();
    }

    function test_HolderCanRegister() public {
        vm.prank(holder);
        registry.registerAgent();

        assertTrue(registry.isRegistered(holder));
        assertTrue(registry.isEligibleAgent(holder));
        assertEq(registry.agentCount(), 1);
        assertEq(registry.registeredAt(holder), block.timestamp);
    }

    function test_RegisterTwiceReverts() public {
        vm.startPrank(holder);
        registry.registerAgent();
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry.AlreadyRegistered.selector, holder));
        registry.registerAgent();
        vm.stopPrank();
    }

    function test_MultipleAgentsCounted() public {
        vm.prank(holder);
        registry.registerAgent();
        vm.prank(holder2);
        registry.registerAgent();
        assertEq(registry.agentCount(), 2);
    }

    function test_DeregisterRemovesEligibility() public {
        vm.startPrank(holder);
        registry.registerAgent();
        registry.deregisterAgent();
        vm.stopPrank();

        assertFalse(registry.isRegistered(holder));
        assertFalse(registry.isEligibleAgent(holder));
        assertEq(registry.agentCount(), 0);
        assertEq(registry.registeredAt(holder), 0);
    }

    function test_DeregisterRevertsWhenNotRegistered() public {
        vm.prank(holder);
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry.NotRegistered.selector, holder));
        registry.deregisterAgent();
    }

    function test_ReregisterAfterDeregister() public {
        vm.startPrank(holder);
        registry.registerAgent();
        registry.deregisterAgent();
        registry.registerAgent();
        vm.stopPrank();
        assertTrue(registry.isEligibleAgent(holder));
        assertEq(registry.agentCount(), 1);
    }

    function test_HoldsAgentIdView() public view {
        assertTrue(registry.holdsAgentId(holder));
        assertFalse(registry.holdsAgentId(stranger));
    }

    function test_EligibilityDropsIfAgentIdBalanceZeroed() public {
        vm.prank(holder);
        registry.registerAgent();
        assertTrue(registry.isEligibleAgent(holder));

        agentId.setBalance(holder, 0);
        assertTrue(registry.isRegistered(holder));
        assertFalse(registry.isEligibleAgent(holder));
    }
}
