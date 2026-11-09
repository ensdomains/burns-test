// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HarborPair} from "../amm/HarborPair.sol";

/// @notice Prices HBR (the pair's token0) in USDH (token1), scaled by 1e18.
contract SpotOracle {
    HarborPair public immutable pair;

    constructor(HarborPair pair_) {
        pair = pair_;
    }

    function price() external view returns (uint256) {
        (uint256 reserveHbr, uint256 reserveUsdh) = pair.getReserves();
        require(reserveHbr > 0, "SpotOracle: no liquidity");
        return (reserveUsdh * 1e18) / reserveHbr;
    }
}
