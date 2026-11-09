// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HarborPeripheryFixture} from "./utils/HarborPeripheryFixture.sol";

contract SavingsTest is HarborPeripheryFixture {
    address internal alice = makeAddr("alice");

    function _deposit(address who, uint256 amount) internal returns (uint256 shares) {
        fundUsdh(who, amount);
        vm.startPrank(who);
        usdh.approve(address(savings), amount);
        shares = savings.deposit(amount, who);
        vm.stopPrank();
    }

    function test_depositIsPricedAtTheCurrentShareValue() public {
        uint256 shares = _deposit(alice, 1_000e18);
        assertEq(shares, 1_000e18);
        assertEq(savings.convertToAssets(shares), 1_000e18);
        assertEq(savings.totalAssets(), SAVINGS_DEPOSIT + 1_000e18);
    }

    function test_redeemPaysTheExitFeeToRemainingHolders() public {
        uint256 shares = _deposit(alice, 1_000e18);
        uint256 saverValue = savings.convertToAssets(savings.balanceOf(saver));

        vm.prank(alice);
        uint256 payout = savings.redeem(shares, alice);
        assertEq(payout, 999e18);
        assertEq(usdh.balanceOf(alice), 999e18);
        assertGt(savings.convertToAssets(savings.balanceOf(saver)), saverValue);
    }

    function test_tokensSentDirectlyAreNotCounted() public {
        fundUsdh(address(savings), 50_000e18);
        assertEq(savings.totalAssets(), SAVINGS_DEPOSIT);
        assertEq(_deposit(alice, 1_000e18), 1_000e18);
    }

    function test_exitFeeIsCapped() public {
        savings.setExitFee(100);
        vm.expectRevert("SavingsVault: fee too high");
        savings.setExitFee(101);
        vm.prank(alice);
        vm.expectRevert("SavingsVault: not owner");
        savings.setExitFee(0);
    }
}
