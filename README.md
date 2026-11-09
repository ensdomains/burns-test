# Harbor

> [!WARNING]
> **This is test material for an automated code audit tool, not a real protocol.** It has never
> been reviewed or deployed, and it is not maintained. Do not deploy it, copy it into other
> projects, or send it real funds.

Harbor is a small DeFi protocol: a governance token, a share vault, staking rewards, an
over-collateralised lending pool with flash loans, a constant-product pair that prices the
collateral, a keeper that liquidates through flash loans, an auction, a capped NFT pass sale, a
signed airdrop and a token bridge. The treasury runs a second set of products on top: a grants
vault, locked staking, a USDH savings vault, an escrow for bidders, a second airdrop round and a
sale of its HBR allocation.

## Contracts

| Contract                     | What it does                                                                                           |
| ---------------------------- | ------------------------------------------------------------------------------------------------------ |
| `token/ERC20.sol`            | Minimal ERC-20 base                                                                                    |
| `token/HarborToken.sol`      | HBR, the governance token, with EIP-2612 permit                                                        |
| `token/MintableToken.sol`    | Owner-managed minters; used for USDH and bridged wHBR                                                  |
| `vault/HarborVault.sol`      | Share vault over HBR; yield is added by the keeper                                                     |
| `staking/StakingRewards.sol` | Stake HBR, earn USDH over a reward period                                                              |
| `amm/HarborPair.sol`         | Constant-product pair (0.3% fee) for HBR/USDH                                                          |
| `oracle/SpotOracle.sol`      | HBR price in USDH, read from the pair                                                                  |
| `lending/LendingPool.sol`    | Borrow USDH against HBR; liquidations; flash loans                                                     |
| `fees/FeeVault.sol`          | Collects flash-loan fees for the treasury                                                              |
| `keeper/Liquidator.sol`      | Protocol keeper that batches liquidations through a flash loan                                         |
| `market/Auction.sol`         | English auction for ETH with pull refunds                                                              |
| `nft/HarborPass.sol`         | ERC-721 pass sale, capped per wallet                                                                   |
| `airdrop/VoucherClaims.sol`  | HBR airdrop claimed with vouchers signed by an off-chain signer                                        |
| `bridge/*`                   | Lock HBR on L1, mint wHBR on L2, and back. Tests run both sides on one chain with a messenger stand-in |
| `access/Owned.sol`           | Single-owner base for contracts configured after deployment                                            |
| `treasury/GrantsVault.sol`   | Grants budget: the treasury approves grants, recipients claim them                                     |
| `treasury/Rescuable.sol`     | Base for recovering tokens sent to a contract by mistake                                               |
| `staking/LockedStaking.sol`  | Stake HBR for at least 30 days, earn USDH                                                              |
| `staking/RewardAccrual.sol`  | Reward bookkeeping shared by staking contracts                                                         |
| `vault/SavingsVault.sol`     | Share vault over USDH; exit fees accrue to remaining holders                                           |
| `market/BidEscrow.sol`       | Holds ETH that bidders set aside between auctions                                                      |
| `airdrop/RetroClaims.sol`    | Second HBR airdrop: one signed voucher per account                                                     |
| `oracle/ReferenceFeed.sol`   | HBR reference price posted by the reporter                                                             |
| `oracle/PairOracle.sol`      | HBR price from the pair, checked against the reference feed                                            |
| `sale/TokenSale.sol`         | Sells the treasury's HBR for USDH at the pair price plus a premium                                     |

## Build and test

```sh
git clone --depth 1 --branch v1.9.7 https://github.com/foundry-rs/forge-std lib/forge-std
forge test
```

Solidity 0.8.28. `test/utils/HarborFixture.sol` deploys and wires the core system, and
`test/utils/HarborPeripheryFixture.sol` adds the treasury products on top of it.
