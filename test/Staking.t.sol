// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HarborFixture} from "./utils/HarborFixture.sol";

contract StakingTest is HarborFixture {
    address internal alice = makeAddr("alice");

    function setUp() public override {
        super.setUp();
        fundHbr(alice, 1_000e18);
        vm.prank(alice);
        hbr.approve(address(staking), type(uint256).max);
    }

    function test_soleStakerEarnsTheWholePeriod() public {
        vm.prank(alice);
        staking.stake(1_000e18);
        // Alice staked at the start of the period.
        skip(staking.REWARDS_DURATION());
        vm.prank(alice);
        staking.getReward();
        assertApproxEqRel(usdh.balanceOf(alice), STAKING_REWARD, 1e15);
    }

    function test_exitReturnsStake() public {
        vm.startPrank(alice);
        staking.stake(1_000e18);
        skip(1 days);
        staking.exit();
        vm.stopPrank();
        assertEq(hbr.balanceOf(alice), 1_000e18);
        assertGt(usdh.balanceOf(alice), 0);
    }

    function test_onlyOwnerStartsPeriods() public {
        vm.prank(alice);
        vm.expectRevert("StakingRewards: not owner");
        staking.notifyRewardAmount(1);
    }
}
