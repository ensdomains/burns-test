// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HarborPeripheryFixture} from "./utils/HarborPeripheryFixture.sol";

contract EscrowTest is HarborPeripheryFixture {
    address internal alice = makeAddr("alice");

    function test_depositAndPartialWithdraw() public {
        vm.deal(alice, 3 ether);
        vm.startPrank(alice);
        escrow.deposit{value: 3 ether}();
        escrow.withdraw(1 ether);
        vm.stopPrank();
        assertEq(escrow.deposits(alice), 2 ether);
        assertEq(alice.balance, 1 ether);
    }

    function test_cannotWithdrawMoreThanDeposited() public {
        vm.deal(alice, 1 ether);
        vm.startPrank(alice);
        escrow.deposit{value: 1 ether}();
        vm.expectRevert("BidEscrow: exceeds deposit");
        escrow.withdraw(2 ether);
        vm.stopPrank();
    }
}
