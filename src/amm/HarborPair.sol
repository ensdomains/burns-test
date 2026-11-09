// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "../token/ERC20.sol";

/// @notice Constant-product pair with a 0.3% swap fee. Liquidity shares are an ERC-20.
contract HarborPair is ERC20 {
    event Swap(address indexed sender, address indexed tokenIn, uint256 amountIn, uint256 amountOut, address to);
    event Sync(uint256 reserve0, uint256 reserve1);

    uint256 public constant MINIMUM_LIQUIDITY = 1e3;

    ERC20 public immutable token0;
    ERC20 public immutable token1;
    uint256 public reserve0;
    uint256 public reserve1;

    constructor(ERC20 token0_, ERC20 token1_) ERC20("Harbor LP", "HLP", 18) {
        token0 = token0_;
        token1 = token1_;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256)
    {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "HarborPair: bad amounts");
        uint256 amountInWithFee = amountIn * 997;
        return (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
    }

    function addLiquidity(uint256 amount0, uint256 amount1, address to)
        external
        returns (uint256 liquidity)
    {
        require(token0.transferFrom(msg.sender, address(this), amount0), "HarborPair: transfer failed");
        require(token1.transferFrom(msg.sender, address(this), amount1), "HarborPair: transfer failed");
        uint256 supply = totalSupply;
        if (supply == 0) {
            liquidity = _sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0xdEaD), MINIMUM_LIQUIDITY);
        } else {
            uint256 l0 = (amount0 * supply) / reserve0;
            uint256 l1 = (amount1 * supply) / reserve1;
            liquidity = l0 < l1 ? l0 : l1;
        }
        require(liquidity > 0, "HarborPair: zero liquidity");
        _mint(to, liquidity);
        _sync();
    }

    function removeLiquidity(uint256 liquidity, address to)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 supply = totalSupply;
        amount0 = (liquidity * reserve0) / supply;
        amount1 = (liquidity * reserve1) / supply;
        _burn(msg.sender, liquidity);
        require(token0.transfer(to, amount0), "HarborPair: transfer failed");
        require(token1.transfer(to, amount1), "HarborPair: transfer failed");
        _sync();
    }

    function swap(ERC20 tokenIn, uint256 amountIn, uint256 minAmountOut, address to)
        external
        returns (uint256 amountOut)
    {
        bool zeroForOne = tokenIn == token0;
        require(zeroForOne || tokenIn == token1, "HarborPair: unknown token");
        (ERC20 tokenOut, uint256 reserveIn, uint256 reserveOut) =
            zeroForOne ? (token1, reserve0, reserve1) : (token0, reserve1, reserve0);

        require(tokenIn.transferFrom(msg.sender, address(this), amountIn), "HarborPair: transfer failed");
        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= minAmountOut, "HarborPair: slippage");
        require(tokenOut.transfer(to, amountOut), "HarborPair: transfer failed");
        _sync();
        emit Swap(msg.sender, address(tokenIn), amountIn, amountOut, to);
    }

    function _sync() internal {
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));
        emit Sync(reserve0, reserve1);
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
