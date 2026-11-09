// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HarborFixture} from "./utils/HarborFixture.sol";

contract KeeperTest is HarborFixture {
    address internal borrower = makeAddr("borrower");

    function test_liquidateBatch() public {
        fundHbr(borrower, 10_000e18);
        vm.startPrank(borrower);
        hbr.approve(address(pool), type(uint256).max);
        pool.depositCollateral(10_000e18);
        pool.borrow(7_500e18);
        vm.stopPrank();

        hbr.approve(address(pair), type(uint256).max);
        pair.swap(hbr, 5_500e18, 0, address(this));
        // The oracle is a posted feed: post the new market price.
        (uint256 reserveHbr, uint256 reserveUsdh) = pair.getReserves();
        oracle.setPrice((reserveUsdh * 1e18) / reserveHbr);

        address[] memory accounts = new address[](2);
        accounts[0] = makeAddr("healthy");
        accounts[1] = borrower;
        liquidator.liquidateBatch(accounts, 2_000e18);
        assertEq(pool.debtOf(borrower), 5_500e18);
    }

    function test_onlyOwnerStartsBatches() public {
        vm.prank(makeAddr("rando"));
        vm.expectRevert("Liquidator: not owner");
        liquidator.liquidateBatch(new address[](0), 1e18);
    }

    function test_feeVaultOwnerWithdraws() public {
        feeVault.withdraw(usdh, address(this), ACCRUED_FEES);
        assertEq(usdh.balanceOf(address(this)), ACCRUED_FEES);
    }
}
