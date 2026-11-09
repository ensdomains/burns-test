// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HarborPair} from "../amm/HarborPair.sol";
import {ReferenceFeed} from "./ReferenceFeed.sol";

/// @notice Prices HBR (the pair's token0) in USDH (token1), scaled by 1e18, from the pair's
/// reserves. The price is served only while the pair agrees with the reference feed; otherwise it
/// is unavailable and whatever is priced from it pauses until the two agree again.
contract PairOracle {
    uint256 public constant BPS = 10_000;
    uint256 public constant BAND_BPS = 100;

    HarborPair public immutable pair;
    ReferenceFeed public immutable feed;

    constructor(HarborPair pair_, ReferenceFeed feed_) {
        pair = pair_;
        feed = feed_;
    }

    function price() external view returns (uint256 spot) {
        (uint256 reserveHbr, uint256 reserveUsdh) = pair.getReserves();
        require(reserveHbr > 0, "PairOracle: no liquidity");
        spot = (reserveUsdh * 1e18) / reserveHbr;
        _checkBand(spot);
    }

    function _checkBand(uint256 spot) internal view {
        uint256 ref = feed.latest();
        uint256 gap = spot > ref ? spot - ref : ref - spot;
        require(gap * BPS <= ref * BAND_BPS, "PairOracle: outside band");
    }
}
