// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "../token/ERC20.sol";

/// @notice Share vault over USDH. Redemptions pay an exit fee that stays in the vault and raises
/// the value of the remaining shares. The first deposit locks a small amount of dead shares.
contract SavingsVault is ERC20 {
    event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Redeem(address indexed owner, address indexed receiver, uint256 assets, uint256 shares);
    event ExitFeeSet(uint256 exitFeeBps);

    address internal constant DEAD = address(0xdEaD);
    uint256 public constant DEAD_SHARES = 1e3;
    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_EXIT_FEE_BPS = 100;

    ERC20 public immutable asset;
    address public immutable owner;
    uint256 public exitFeeBps;

    uint256 internal managed;

    constructor(ERC20 asset_, uint256 exitFeeBps_) ERC20("Harbor Savings Share", "hsUSDH", 18) {
        require(exitFeeBps_ <= MAX_EXIT_FEE_BPS, "SavingsVault: fee too high");
        asset = asset_;
        owner = msg.sender;
        exitFeeBps = exitFeeBps_;
    }

    function totalAssets() public view returns (uint256) {
        return managed;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    function setExitFee(uint256 exitFeeBps_) external {
        require(msg.sender == owner, "SavingsVault: not owner");
        require(exitFeeBps_ <= MAX_EXIT_FEE_BPS, "SavingsVault: fee too high");
        exitFeeBps = exitFeeBps_;
        emit ExitFeeSet(exitFeeBps_);
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        require(assets > 0, "SavingsVault: zero assets");
        require(asset.transferFrom(msg.sender, address(this), assets), "SavingsVault: transfer failed");

        uint256 supply = totalSupply;
        if (supply == 0) {
            require(assets > DEAD_SHARES, "SavingsVault: first deposit too small");
            _mint(DEAD, DEAD_SHARES);
            shares = assets - DEAD_SHARES;
        } else {
            shares = (assets * supply) / totalAssets();
        }
        require(shares > 0, "SavingsVault: zero shares");

        managed += assets;
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver) external returns (uint256 payout) {
        uint256 assets = convertToAssets(shares);
        require(assets > 0, "SavingsVault: zero assets");
        uint256 fee = (assets * exitFeeBps + BPS - 1) / BPS;
        payout = assets - fee;
        _burn(msg.sender, shares);
        managed -= payout;
        require(asset.transfer(receiver, payout), "SavingsVault: transfer failed");
        emit Redeem(msg.sender, receiver, payout, shares);
    }
}
