// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import {IGelatoUniV3Pool} from "./interfaces/IGelatoUniV3Pool.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "./vendor/uniswap/TickMath.sol";
import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LiquidityAmounts} from "./vendor/uniswap/LiquidityAmounts.sol";
import "hardhat/console.sol";

contract GelatoUniV3Router {
    using SafeERC20 for IERC20;
    using TickMath for int24;

    function mintFromMaxAmounts(
        IGelatoUniV3Pool gUniPool,
        uint256 amount0Max,
        uint256 amount1Max
    )
        external
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 mintAmount
        )
    {
        IUniswapV3Pool pool = gUniPool.pool();
        (uint128 liquidity, , , , ) = pool.positions(gUniPool.getPositionID());
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        uint160 sqrtRatioLowerTick =
            gUniPool.currentLowerTick().getSqrtRatioAtTick();
        uint160 sqrtRatioUpperTick =
            gUniPool.currentUpperTick().getSqrtRatioAtTick();
        uint128 newLiquidity =
            _getLiquidity(
                gUniPool,
                amount0Max,
                amount1Max,
                liquidity,
                sqrtRatioX96,
                sqrtRatioLowerTick,
                sqrtRatioUpperTick
            );

        return gUniPool.mint(newLiquidity, msg.sender);
    }

    function _getLiquidity(
        IGelatoUniV3Pool gUniPool,
        uint256 amount0Max,
        uint256 amount1Max,
        uint128 liquidity,
        uint160 sqrtRatioX96,
        uint160 sqrtRatioLowerTick,
        uint160 sqrtRatioUpperTick
    ) internal view returns (uint128) {
        uint128 newLiquidity =
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                sqrtRatioLowerTick,
                sqrtRatioUpperTick,
                amount0Max,
                amount1Max
            );
        (uint256 amount0Final, uint256 amount1Final) =
            _getAdjustedAmounts(
                gUniPool,
                newLiquidity,
                liquidity,
                amount0Max,
                amount1Max
            );
        if (amount0Final != amount0Max || amount1Final != amount1Max) {
            newLiquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                sqrtRatioLowerTick,
                sqrtRatioUpperTick,
                amount0Final,
                amount1Final
            );
        }

        return newLiquidity;
    }

    function _getAdjustedAmounts(
        IGelatoUniV3Pool gUniPool,
        uint128 newLiquidity,
        uint128 liquidity,
        uint256 amount0Max,
        uint256 amount1Max
    ) internal view returns (uint256 amount0, uint256 amount1) {
        if (liquidity == 0) {
            return (amount0Max, amount1Max);
        }
        uint256 balance0 = gUniPool.token0().balanceOf(address(gUniPool));
        uint256 balance1 = gUniPool.token1().balanceOf(address(gUniPool));
        uint256 proportionBPS =
            (uint256(newLiquidity) * 10000) / uint256(liquidity);
        uint256 amount0Additional = (balance0 * proportionBPS) / 10000;
        uint256 amount1Additional = (balance1 * proportionBPS) / 10000;
        amount0 = amount0Max - amount0Additional;
        amount1 = amount1Max - amount1Additional;
    }

    function getExpectedAmount1(IGelatoUniV3Pool gUniPool, uint256 amount0Max)
        external
        view
        returns (uint128 newLiquidity, uint256 amount1Expected)
    {
        IUniswapV3Pool pool = gUniPool.pool();
        (uint128 liquidity, , , , ) = pool.positions(gUniPool.getPositionID());
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        uint160 sqrtRatioLowerTick =
            gUniPool.currentLowerTick().getSqrtRatioAtTick();
        uint160 sqrtRatioUpperTick =
            gUniPool.currentUpperTick().getSqrtRatioAtTick();
        newLiquidity = _getLiquidity(
            gUniPool,
            amount0Max,
            type(uint256).max,
            liquidity,
            sqrtRatioX96,
            sqrtRatioLowerTick,
            sqrtRatioUpperTick
        );
        (, amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            sqrtRatioLowerTick,
            sqrtRatioUpperTick,
            newLiquidity
        );
    }

    function getExpectedAmount0(IGelatoUniV3Pool gUniPool, uint256 amount1Max)
        external
        view
        returns (uint128 newLiquidity, uint256 amount0Expected)
    {
        IUniswapV3Pool pool = gUniPool.pool();
        (uint128 liquidity, , , , ) = pool.positions(gUniPool.getPositionID());
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        uint160 sqrtRatioLowerTick =
            gUniPool.currentLowerTick().getSqrtRatioAtTick();
        uint160 sqrtRatioUpperTick =
            gUniPool.currentUpperTick().getSqrtRatioAtTick();
        newLiquidity = _getLiquidity(
            gUniPool,
            type(uint256).max,
            amount1Max,
            liquidity,
            sqrtRatioX96,
            sqrtRatioLowerTick,
            sqrtRatioUpperTick
        );
        (amount0Expected, ) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            sqrtRatioLowerTick,
            sqrtRatioUpperTick,
            newLiquidity
        );
    }
}
