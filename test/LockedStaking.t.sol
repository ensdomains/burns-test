// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HarborPeripheryFixture} from "./utils/HarborPeripheryFixture.sol";

contract LockedStakingTest is HarborPeripheryFixture {
    address internal alice = makeAddr("alice");

    function _stake(address who, uint256 amount) internal {
        fundHbr(who, amount);
        vm.startPrank(who);
        hbr.approve(address(lockedStaking), amount);
        lockedStaking.stake(amount);
        vm.stopPrank();
    }

    function test_soleStakerEarnsTheWholePeriod() public {
        vm.warp(block.timestamp + 7 days);
        assertApproxEqAbs(lockedStaking.earned(staker), LOCKED_REWARD, 1e12);
        vm.prank(staker);
        lockedStaking.claim();
        assertApproxEqAbs(usdh.balanceOf(staker), LOCKED_REWARD, 1e12);
        assertEq(lockedStaking.rewards(staker), 0);
    }

    function test_lateStakerEarnsOnlyFromArrival() public {
        vm.warp(block.timestamp + 3.5 days);
        _stake(alice, LOCKED_STAKE);
        assertEq(lockedStaking.earned(alice), 0);

        vm.warp(block.timestamp + 3.5 days);
        assertApproxEqAbs(lockedStaking.earned(alice), LOCKED_REWARD / 4, 1e12);
        assertApproxEqAbs(lockedStaking.earned(staker), (LOCKED_REWARD * 3) / 4, 1e12);
    }

    function test_withdrawWaitsForTheLock() public {
        vm.prank(staker);
        vm.expectRevert("LockedStaking: locked");
        lockedStaking.withdraw(1e18);

        vm.warp(block.timestamp + 30 days);
        vm.prank(staker);
        lockedStaking.withdraw(LOCKED_STAKE);
        assertEq(hbr.balanceOf(staker), LOCKED_STAKE);
    }

    function test_onlyOwnerStartsPeriods() public {
        vm.prank(alice);
        vm.expectRevert("LockedStaking: not owner");
        lockedStaking.notifyRewardAmount(1e18);
    }
}
