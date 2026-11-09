// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HarborFixture} from "./utils/HarborFixture.sol";

contract BridgeTest is HarborFixture {
    address internal alice = makeAddr("alice");

    function test_roundTrip() public {
        fundHbr(alice, 100e18);
        vm.startPrank(alice);
        hbr.approve(address(l1Gateway), 100e18);
        l1Gateway.deposit(alice, 100e18);
        assertEq(wHbr.balanceOf(alice), 100e18);

        l2Gateway.withdraw(alice, 40e18);
        vm.stopPrank();
        assertEq(wHbr.balanceOf(alice), 60e18);
        assertEq(hbr.balanceOf(alice), 40e18);
    }

    function test_withdrawalMustComeFromL2Gateway() public {
        fundHbr(alice, 100e18);
        vm.startPrank(alice);
        hbr.approve(address(l1Gateway), 100e18);
        l1Gateway.deposit(alice, 100e18);
        vm.expectRevert("L1Gateway: not from L2 gateway");
        messenger.sendMessage(
            address(l1Gateway), abi.encodeCall(l1Gateway.finalizeWithdrawal, (alice, 100e18))
        );
        vm.stopPrank();
    }
}
