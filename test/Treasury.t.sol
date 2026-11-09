// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HarborPeripheryFixture} from "./utils/HarborPeripheryFixture.sol";

contract TreasuryTest is HarborPeripheryFixture {
    address internal alice = makeAddr("alice");

    function test_grantIsClaimedOnce() public {
        grants.approveGrant(alice, 1_000e18);
        vm.prank(alice);
        grants.claim();
        assertEq(hbr.balanceOf(alice), 1_000e18);
        assertEq(grants.outstanding(), 0);

        vm.prank(alice);
        vm.expectRevert("GrantsVault: nothing granted");
        grants.claim();
    }

    function test_grantsStayWithinBudget() public {
        vm.expectRevert("GrantsVault: over budget");
        grants.approveGrant(alice, GRANTS_BUDGET + 1);
    }

    function test_onlyOwnerApprovesAndRescues() public {
        vm.startPrank(alice);
        vm.expectRevert("Owned: not owner");
        grants.approveGrant(alice, 1e18);
        vm.expectRevert("Owned: not owner");
        grants.rescue(usdh, alice, 1e18);
        vm.stopPrank();

        fundUsdh(address(grants), 5e18);
        grants.rescue(usdh, alice, 5e18);
        assertEq(usdh.balanceOf(alice), 5e18);
    }

    function test_initializeRunsOnce() public {
        vm.expectRevert("Owned: already set");
        grants.initialize(alice, hbr);
    }
}
