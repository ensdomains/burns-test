// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HarborFixture} from "./utils/HarborFixture.sol";
import {IFlashBorrower} from "../src/lending/IFlashBorrower.sol";
import {LendingPool} from "../src/lending/LendingPool.sol";

contract HonestBorrower is IFlashBorrower {
    LendingPool internal immutable pool;

    constructor(LendingPool pool_) {
        pool = pool_;
    }

    function borrow(uint256 amount) external {
        pool.flashLoan(this, amount, "");
    }

    function onFlashLoan(address, address, uint256 amount, uint256 fee, bytes calldata)
        external
        returns (bytes32)
    {
        pool.debtToken().approve(address(pool), amount + fee);
        return pool.CALLBACK_SUCCESS();
    }
}

contract LendingTest is HarborFixture {
    address internal borrower = makeAddr("borrower");

    function setUp() public override {
        super.setUp();
        fundHbr(borrower, 10_000e18);
        vm.startPrank(borrower);
        hbr.approve(address(pool), type(uint256).max);
        usdh.approve(address(pool), type(uint256).max);
        pool.depositCollateral(10_000e18);
        vm.stopPrank();
    }

    function test_borrowUpToLtv() public {
        vm.prank(borrower);
        pool.borrow(7_500e18);
        assertEq(usdh.balanceOf(borrower), 7_500e18);
    }

    function test_borrowAboveLtvReverts() public {
        vm.prank(borrower);
        vm.expectRevert("LendingPool: exceeds borrow limit");
        pool.borrow(7_501e18);
    }

    function test_repayClearsDebt() public {
        vm.startPrank(borrower);
        pool.borrow(1_000e18);
        pool.repay(borrower, 1_000e18);
        vm.stopPrank();
        assertEq(pool.debtOf(borrower), 0);
    }

    function test_liquidationAfterPriceDrop() public {
        vm.prank(borrower);
        pool.borrow(7_500e18);
        // HBR falls ~10% after a large sale.
        hbr.approve(address(pair), type(uint256).max);
        pair.swap(hbr, 5_500e18, 0, address(this));
        assertTrue(pool.isLiquidatable(borrower));

        address keeper = makeAddr("keeper");
        fundUsdh(keeper, 1_000e18);
        vm.startPrank(keeper);
        usdh.approve(address(pool), type(uint256).max);
        uint256 seized = pool.liquidate(borrower, 1_000e18);
        vm.stopPrank();
        assertGt(seized, 1_000e18);
        assertEq(pool.debtOf(borrower), 6_500e18);
    }

    function test_flashLoanChargesFee() public {
        HonestBorrower flash = new HonestBorrower(pool);
        fundUsdh(address(flash), 100e18);
        uint256 feesBefore = usdh.balanceOf(address(feeVault));
        flash.borrow(100_000e18);
        assertEq(usdh.balanceOf(address(feeVault)) - feesBefore, 90e18);
    }

    function test_lenderWithdraws() public {
        vm.prank(lender);
        pool.withdrawSupply(1_000e18);
        assertEq(usdh.balanceOf(lender), 1_000e18);
    }
}
