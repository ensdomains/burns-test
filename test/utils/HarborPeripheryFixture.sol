// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HarborFixture} from "./HarborFixture.sol";

import {GrantsVault} from "../../src/treasury/GrantsVault.sol";
import {LockedStaking} from "../../src/staking/LockedStaking.sol";
import {SavingsVault} from "../../src/vault/SavingsVault.sol";
import {BidEscrow} from "../../src/market/BidEscrow.sol";
import {RetroClaims} from "../../src/airdrop/RetroClaims.sol";
import {ReferenceFeed} from "../../src/oracle/ReferenceFeed.sol";
import {PairOracle} from "../../src/oracle/PairOracle.sol";
import {TokenSale} from "../../src/sale/TokenSale.sol";

/// @notice The core deployment of `HarborFixture` plus the treasury products: grants, locked
/// staking, the savings vault, the bid escrow, the second airdrop and the token sale. As in the
/// core fixture, the test contract is the deployer, owner and treasury.
abstract contract HarborPeripheryFixture is HarborFixture {
    uint256 internal constant GRANTS_BUDGET = 500_000e18;
    uint256 internal constant LOCKED_REWARD = 70_000e18;
    uint256 internal constant LOCKED_STAKE = 200_000e18;
    uint256 internal constant SAVINGS_DEPOSIT = 300_000e18;
    uint256 internal constant SAVINGS_EXIT_FEE_BPS = 10;
    uint256 internal constant ESCROW_DEPOSIT = 50 ether;
    uint256 internal constant RETRO_POOL = 1_000_000e18;
    uint256 internal constant SALE_ALLOCATION = 2_000_000e18;
    uint256 internal constant REFERENCE_PRICE = 1e18;

    GrantsVault internal grants;
    LockedStaking internal lockedStaking;
    SavingsVault internal savings;
    BidEscrow internal escrow;
    RetroClaims internal retro;
    ReferenceFeed internal feed;
    PairOracle internal pairOracle;
    TokenSale internal sale;

    address internal reporter = makeAddr("reporter");
    address internal staker = makeAddr("staker");
    address internal saver = makeAddr("saver");
    address internal bidder = makeAddr("bidder");

    function setUp() public virtual override {
        super.setUp();

        grants = new GrantsVault();
        grants.initialize(address(this), hbr);
        hbr.transfer(address(grants), GRANTS_BUDGET);

        // Locked staking, with a reward period running and one account staked.
        lockedStaking = new LockedStaking(hbr, usdh);
        usdh.mint(address(lockedStaking), LOCKED_REWARD);
        lockedStaking.notifyRewardAmount(LOCKED_REWARD);
        hbr.transfer(staker, LOCKED_STAKE);
        vm.startPrank(staker);
        hbr.approve(address(lockedStaking), LOCKED_STAKE);
        lockedStaking.stake(LOCKED_STAKE);
        vm.stopPrank();

        // Savings vault, with one depositor.
        savings = new SavingsVault(usdh, SAVINGS_EXIT_FEE_BPS);
        usdh.mint(saver, SAVINGS_DEPOSIT);
        vm.startPrank(saver);
        usdh.approve(address(savings), SAVINGS_DEPOSIT);
        savings.deposit(SAVINGS_DEPOSIT, saver);
        vm.stopPrank();

        escrow = new BidEscrow();
        vm.deal(bidder, ESCROW_DEPOSIT);
        vm.prank(bidder);
        escrow.deposit{value: ESCROW_DEPOSIT}();

        retro = new RetroClaims(hbr, voucherSigner);
        hbr.transfer(address(retro), RETRO_POOL);

        // Token sale, priced from the pair and checked against the reporter's reference price.
        feed = new ReferenceFeed(reporter);
        vm.prank(reporter);
        feed.post(REFERENCE_PRICE);
        pairOracle = new PairOracle(pair, feed);
        sale = new TokenSale(hbr, usdh, pairOracle, address(this));
        hbr.transfer(address(sale), SALE_ALLOCATION);
    }

    function signRetroVoucher(address account, uint256 amount)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        return vm.sign(voucherSignerKey, retro.voucherDigest(account, amount));
    }
}
