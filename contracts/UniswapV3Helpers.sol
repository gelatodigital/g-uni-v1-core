// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import {
  LiquidityAmounts
} from "./vendor/uniswap/LiquidityAmounts.sol";
import {
  TickMath
} from "./vendor/uniswap/TickMath.sol";

contract UniswapV3Helpers {
    using TickMath for int24;

    constructor() {} // solhint-disable-line no-empty-blocks

    function getLiquidityForAmounts(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0,
        uint256 amount1
    )
        external
        pure
        returns (uint128 liquidity)
    {
        return LiquidityAmounts.getLiquidityForAmounts(
            sqrtRatioX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            amount0,
            amount1
        );
    }

    function getAmountsForLiquidity(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) external pure returns (uint256 amount0, uint256 amount1) {
        return LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            liquidity
        );
    }

    function getLiquidityForAmounts(
        uint160 sqrtRatioX96,
        int24 lowerTick,
        int24 upperTick,
        uint256 amount0,
        uint256 amount1
    )
        external
        pure
        returns (uint128 liquidity)
    {
        return LiquidityAmounts.getLiquidityForAmounts(
            sqrtRatioX96,
            lowerTick.getSqrtRatioAtTick(),
            upperTick.getSqrtRatioAtTick(),
            amount0,
            amount1
        );
    }

    function getAmountsForLiquidity(
        uint160 sqrtRatioX96,
        int24 lowerTick,
        int24 upperTick,
        uint128 liquidity
    ) external pure returns (uint256 amount0, uint256 amount1) {
        return LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            lowerTick.getSqrtRatioAtTick(),
            upperTick.getSqrtRatioAtTick(),
            liquidity
        );
    }

    function getSqrtRatioAtTick(int24 tick) external pure returns (uint160 sqrtPriceX96) {
        return tick.getSqrtRatioAtTick();
    }
}