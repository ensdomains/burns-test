// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HarborFixture} from "./utils/HarborFixture.sol";

contract VaultTest is HarborFixture {
    address internal alice = makeAddr("alice");

    function setUp() public override {
        super.setUp();
        fundHbr(alice, 10_000e18);
        vm.prank(alice);
        hbr.approve(address(vault), type(uint256).max);
    }

    function test_firstDepositLocksDeadShares() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(1_000e18, alice);
        assertEq(shares, 1_000e18 - vault.DEAD_SHARES());
        assertEq(vault.totalSupply(), 1_000e18);
    }

    function test_redeemReturnsDeposit() public {
        vm.startPrank(alice);
        uint256 shares = vault.deposit(1_000e18, alice);
        uint256 assets = vault.redeem(shares, alice);
        vm.stopPrank();
        assertEq(assets, shares);
        assertEq(hbr.balanceOf(alice), 10_000e18 - vault.DEAD_SHARES());
    }

    function test_yieldRaisesShareValue() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(1_000e18, alice);
        hbr.transfer(address(vault), 100e18); // keeper adds yield
        assertGt(vault.convertToAssets(shares), shares);
    }

    function test_firstDepositMustExceedDeadShares() public {
        vm.prank(alice);
        vm.expectRevert("HarborVault: first deposit too small");
        vault.deposit(1_000, alice);
    }
}
