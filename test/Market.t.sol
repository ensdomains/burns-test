// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HarborFixture} from "./utils/HarborFixture.sol";

contract MarketTest is HarborFixture {
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public override {
        super.setUp();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_outbidBidderWithdraws() public {
        vm.prank(alice);
        auction.bid{value: 1 ether}();
        vm.prank(bob);
        auction.bid{value: 2 ether}();

        vm.prank(alice);
        auction.withdraw();
        assertEq(alice.balance, 10 ether);
        assertEq(auction.pendingReturns(alice), 0);
    }

    function test_settlePaysSeller() public {
        vm.prank(alice);
        auction.bid{value: 1 ether}();
        skip(3 days);
        uint256 before = address(this).balance;
        auction.settle();
        assertEq(address(this).balance - before, 1 ether);
    }

    function test_passMintAndCap() public {
        vm.startPrank(alice);
        pass.mint{value: 0.1 ether}(2);
        vm.expectRevert("HarborPass: wallet cap");
        pass.mint{value: 0.05 ether}(1);
        vm.stopPrank();
        assertEq(pass.balanceOf(alice), 2);
    }

    function test_voucherClaimOnce() public {
        bytes memory sig = signVoucher(alice, 500e18);
        vouchers.claim(alice, 500e18, sig);
        assertEq(hbr.balanceOf(alice), 500e18);

        vm.expectRevert("VoucherClaims: already redeemed");
        vouchers.claim(alice, 500e18, sig);
    }

    function test_voucherRejectsOtherAmounts() public {
        bytes memory sig = signVoucher(alice, 500e18);
        vm.expectRevert("VoucherClaims: bad signature");
        vouchers.claim(alice, 5_000e18, sig);
    }
}
