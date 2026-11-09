// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HarborPeripheryFixture} from "./utils/HarborPeripheryFixture.sol";

contract SaleTest is HarborPeripheryFixture {
    address internal alice = makeAddr("alice");

    function test_buyAtPairPricePlusPremium() public {
        fundUsdh(alice, 1_020e18);
        uint256 treasuryBefore = usdh.balanceOf(address(this));
        vm.startPrank(alice);
        usdh.approve(address(sale), 1_020e18);
        uint256 cost = sale.buy(1_000e18, 1_020e18);
        vm.stopPrank();
        assertEq(cost, 1_020e18);
        assertEq(hbr.balanceOf(alice), 1_000e18);
        assertEq(usdh.balanceOf(address(this)) - treasuryBefore, 1_020e18);
    }

    function test_quoteRoundsUp() public view {
        assertEq(sale.quote(1), 2);
    }

    function test_buyRespectsMaxCost() public {
        fundUsdh(alice, 1_020e18);
        vm.startPrank(alice);
        usdh.approve(address(sale), 1_020e18);
        vm.expectRevert("TokenSale: price moved");
        sale.buy(1_000e18, 1_019e18);
        vm.stopPrank();
    }

    function test_noSalesOnAStaleReference() public {
        vm.warp(block.timestamp + 2 hours);
        vm.expectRevert("ReferenceFeed: stale");
        sale.quote(1e18);

        vm.prank(reporter);
        feed.post(REFERENCE_PRICE);
        assertEq(sale.quote(1e18), 1.02e18);
    }

    function test_onlyReporterPosts() public {
        vm.prank(alice);
        vm.expectRevert("ReferenceFeed: not reporter");
        feed.post(2e18);
    }

    function test_treasuryWithdrawsUnsold() public {
        sale.withdrawUnsold(alice, 10e18);
        assertEq(hbr.balanceOf(alice), 10e18);
        vm.prank(alice);
        vm.expectRevert("TokenSale: not treasury");
        sale.withdrawUnsold(alice, 10e18);
    }
}
