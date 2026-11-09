// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "../token/ERC20.sol";
import {PairOracle} from "../oracle/PairOracle.sol";

/// @notice Sells the treasury's HBR allocation for USDH at the pair's price plus a 2% premium.
/// Proceeds go straight to the treasury.
contract TokenSale {
    event Sold(address indexed buyer, uint256 amount, uint256 cost);

    uint256 public constant BPS = 10_000;
    uint256 public constant PREMIUM_BPS = 200;

    ERC20 public immutable hbr;
    ERC20 public immutable usdh;
    PairOracle public immutable oracle;
    address public immutable treasury;

    constructor(ERC20 hbr_, ERC20 usdh_, PairOracle oracle_, address treasury_) {
        hbr = hbr_;
        usdh = usdh_;
        oracle = oracle_;
        treasury = treasury_;
    }

    /// @notice USDH owed for `amount` HBR at the current price, rounded up.
    function quote(uint256 amount) public view returns (uint256) {
        uint256 numerator = amount * oracle.price() * (BPS + PREMIUM_BPS);
        uint256 denominator = 1e18 * BPS;
        return (numerator + denominator - 1) / denominator;
    }

    function buy(uint256 amount, uint256 maxCost) external returns (uint256 cost) {
        require(amount > 0, "TokenSale: zero amount");
        cost = quote(amount);
        require(cost <= maxCost, "TokenSale: price moved");
        require(usdh.transferFrom(msg.sender, treasury, cost), "TokenSale: payment failed");
        require(hbr.transfer(msg.sender, amount), "TokenSale: transfer failed");
        emit Sold(msg.sender, amount, cost);
    }

    function withdrawUnsold(address to, uint256 amount) external {
        require(msg.sender == treasury, "TokenSale: not treasury");
        require(hbr.transfer(to, amount), "TokenSale: transfer failed");
    }
}
