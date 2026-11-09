// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {ERC20} from "../../src/token/ERC20.sol";
import {HarborToken} from "../../src/token/HarborToken.sol";
import {MintableToken} from "../../src/token/MintableToken.sol";
import {HarborVault} from "../../src/vault/HarborVault.sol";
import {StakingRewards} from "../../src/staking/StakingRewards.sol";
import {HarborPair} from "../../src/amm/HarborPair.sol";
import {SpotOracle} from "../../src/oracle/SpotOracle.sol";
import {LendingPool} from "../../src/lending/LendingPool.sol";
import {FeeVault} from "../../src/fees/FeeVault.sol";
import {Liquidator} from "../../src/keeper/Liquidator.sol";
import {Auction} from "../../src/market/Auction.sol";
import {HarborPass} from "../../src/nft/HarborPass.sol";
import {VoucherClaims} from "../../src/airdrop/VoucherClaims.sol";
import {CrossDomainMessenger} from "../../src/bridge/CrossDomainMessenger.sol";
import {L1Gateway} from "../../src/bridge/L1Gateway.sol";
import {L2Gateway} from "../../src/bridge/L2Gateway.sol";

/// @notice Deploys and wires the whole protocol as it runs on mainnet. The test contract is the
/// deployer and owner of everything.
abstract contract HarborFixture is Test {
    uint256 internal constant HBR_SUPPLY = 100_000_000e18;
    uint256 internal constant PAIR_HBR = 100_000e18;
    uint256 internal constant PAIR_USDH = 100_000e18;
    uint256 internal constant POOL_LIQUIDITY = 1_000_000e18;
    uint256 internal constant LIQUIDATOR_BUFFER = 10_000e18;
    uint256 internal constant STAKING_REWARD = 70_000e18;
    uint256 internal constant AIRDROP_POOL = 1_000_000e18;
    uint256 internal constant ACCRUED_FEES = 25_000e18;

    HarborToken internal hbr;
    MintableToken internal usdh;
    HarborVault internal vault;
    StakingRewards internal staking;
    HarborPair internal pair;
    SpotOracle internal oracle;
    FeeVault internal feeVault;
    LendingPool internal pool;
    Liquidator internal liquidator;
    Auction internal auction;
    HarborPass internal pass;
    VoucherClaims internal vouchers;
    CrossDomainMessenger internal messenger;
    MintableToken internal wHbr;
    L1Gateway internal l1Gateway;
    L2Gateway internal l2Gateway;

    address internal lender = makeAddr("lender");
    uint256 internal voucherSignerKey = 0xA11CE;
    address internal voucherSigner = vm.addr(voucherSignerKey);

    function setUp() public virtual {
        hbr = new HarborToken(address(this), HBR_SUPPLY);
        usdh = new MintableToken("Harbor USD", "USDH");
        usdh.setMinter(address(this), true);

        // HBR/USDH pair at a price of 1 USDH per HBR.
        pair = new HarborPair(hbr, usdh);
        usdh.mint(address(this), PAIR_USDH);
        hbr.approve(address(pair), PAIR_HBR);
        usdh.approve(address(pair), PAIR_USDH);
        pair.addLiquidity(PAIR_HBR, PAIR_USDH, address(this));
        oracle = new SpotOracle(pair);

        // Fee vault, with fees accrued so far.
        feeVault = new FeeVault();
        feeVault.initialize(address(this));
        usdh.mint(address(feeVault), ACCRUED_FEES);

        // Lending pool, funded by a lender.
        pool = new LendingPool(hbr, usdh, oracle, address(feeVault));
        usdh.mint(lender, POOL_LIQUIDITY);
        vm.startPrank(lender);
        usdh.approve(address(pool), POOL_LIQUIDITY);
        pool.supply(POOL_LIQUIDITY);
        vm.stopPrank();

        liquidator = new Liquidator(pool, pair);
        usdh.mint(address(liquidator), LIQUIDATOR_BUFFER);

        vault = new HarborVault(hbr);

        staking = new StakingRewards(hbr, usdh);
        usdh.mint(address(staking), STAKING_REWARD);
        staking.notifyRewardAmount(STAKING_REWARD);

        auction = new Auction(address(this), 3 days);
        pass = new HarborPass();

        vouchers = new VoucherClaims(hbr, voucherSigner);
        hbr.transfer(address(vouchers), AIRDROP_POOL);

        messenger = new CrossDomainMessenger();
        wHbr = new MintableToken("Wrapped Harbor", "wHBR");
        l1Gateway = new L1Gateway(hbr, messenger);
        l2Gateway = new L2Gateway(wHbr, messenger);
        l1Gateway.setCounterpart(address(l2Gateway));
        l2Gateway.setCounterpart(address(l1Gateway));
        wHbr.setMinter(address(l2Gateway), true);
    }

    /// @dev Gives `to` HBR from the treasury (this contract).
    function fundHbr(address to, uint256 amount) internal {
        hbr.transfer(to, amount);
    }

    function fundUsdh(address to, uint256 amount) internal {
        usdh.mint(to, amount);
    }

    function signVoucher(address account, uint256 amount) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voucherSignerKey, vouchers.voucherDigest(account, amount));
        return abi.encodePacked(r, s, v);
    }

    receive() external payable {}
}
