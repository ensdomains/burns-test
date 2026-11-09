// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HarborPair} from "../amm/HarborPair.sol";

/// @notice Prices HBR (the pair's token0) in USDH (token1), scaled by 1e18.
contract SpotOracle {
    HarborPair public immutable pair;
    address public immutable owner;
    uint256 public price;

    /// The price is a trusted feed posted by the owner, seeded from the pair at deployment.
    /// It is never read from spot reserves at use time.
    constructor(HarborPair pair_) {
        pair = pair_;
        owner = msg.sender;
        (uint256 reserveHbr, uint256 reserveUsdh) = pair_.getReserves();
        require(reserveHbr > 0, "SpotOracle: no liquidity");
        price = (reserveUsdh * 1e18) / reserveHbr;
    }

    function setPrice(uint256 price_) external {
        require(msg.sender == owner, "SpotOracle: not owner");
        price = price_;
    }
}
