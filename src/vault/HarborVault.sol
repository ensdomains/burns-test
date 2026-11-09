// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "../token/ERC20.sol";

/// @notice Share vault over HBR. Yield arrives as HBR sent to the vault, which raises the value of
/// every share. The first deposit locks a small amount of dead shares.
contract HarborVault is ERC20 {
    event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Redeem(address indexed owner, address indexed receiver, uint256 assets, uint256 shares);

    address internal constant DEAD = address(0xdEaD);
    uint256 public constant DEAD_SHARES = 1e3;

    ERC20 public immutable asset;

    constructor(ERC20 asset_) ERC20("Harbor Vault Share", "hvHBR", 18) {
        asset = asset_;
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        require(assets > 0, "HarborVault: zero assets");
        uint256 assetsBefore = totalAssets();
        require(asset.transferFrom(msg.sender, address(this), assets), "HarborVault: transfer failed");

        uint256 supply = totalSupply;
        if (supply == 0) {
            require(assets > DEAD_SHARES, "HarborVault: first deposit too small");
            _mint(DEAD, DEAD_SHARES);
            shares = assets - DEAD_SHARES;
        } else {
            shares = (assets * supply) / assetsBefore;
        }
        require(shares > 0, "HarborVault: zero shares");

        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver) external returns (uint256 assets) {
        assets = convertToAssets(shares);
        require(assets > 0, "HarborVault: zero assets");
        _burn(msg.sender, shares);
        require(asset.transfer(receiver, assets), "HarborVault: transfer failed");
        emit Redeem(msg.sender, receiver, assets, shares);
    }
}
