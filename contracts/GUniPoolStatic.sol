// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import {
    IUniswapV3MintCallback
} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3SwapCallback
} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {GUniPoolStaticStorage} from "./abstract/GUniPoolStaticStorage.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "./vendor/uniswap/TickMath.sol";
import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    FullMath,
    LiquidityAmounts
} from "./vendor/uniswap/LiquidityAmounts.sol";

contract GUniPoolStatic is
    IUniswapV3MintCallback,
    IUniswapV3SwapCallback,
    GUniPoolStaticStorage
{
    using SafeERC20 for IERC20;
    using TickMath for int24;

    event Minted(
        address receiver,
        uint256 mintAmount,
        uint256 amount0In,
        uint256 amount1In,
        uint128 liquidityMinted
    );

    event Burned(
        address receiver,
        uint256 burnAmount,
        uint256 amount0Out,
        uint256 amount1Out,
        uint128 liquidityBurned
    );

    event Rebalance(int24 lowerTick_, int24 upperTick_);

    // solhint-disable-next-line max-line-length
    constructor(address payable _gelato) GUniPoolStaticStorage(_gelato) {} // solhint-disable-line no-empty-blocks

    // solhint-disable-next-line function-max-lines, code-complexity
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata /*_data*/
    ) external override {
        require(msg.sender == address(pool));

        if (amount0Owed > 0) token0.safeTransfer(msg.sender, amount0Owed);
        if (amount1Owed > 0) token1.safeTransfer(msg.sender, amount1Owed);
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata /*data*/
    ) external override {
        require(msg.sender == address(pool));

        if (amount0Delta > 0)
            token0.safeTransfer(msg.sender, uint256(amount0Delta));
        else if (amount1Delta > 0)
            token1.safeTransfer(msg.sender, uint256(amount1Delta));
    }

    // User functions => Should be called via a Router

    // solhint-disable-next-line function-max-lines, code-complexity
    function mint(uint256 mintAmount, address receiver)
        external
        nonReentrant
        returns (
            uint256 amount0,
            uint256 amount1,
            uint128 liquidityMinted
        )
    {
        require(mintAmount > 0, "mint 0");

        uint256 totalSupply = totalSupply();

        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();

        if (totalSupply > 0) {
            (uint256 amount0Current, uint256 amount1Current) =
                getUnderlyingBalances();

            amount0 = FullMath.mulDivRoundingUp(
                amount0Current,
                mintAmount,
                totalSupply
            );
            amount1 = FullMath.mulDivRoundingUp(
                amount1Current,
                mintAmount,
                totalSupply
            );
        } else {
            // if supply is 0 mintAmount == liquidity to deposit
            (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                lowerTick.getSqrtRatioAtTick(),
                upperTick.getSqrtRatioAtTick(),
                uint128(mintAmount)
            );
        }

        // transfer amounts owed to contract
        if (amount0 > 0) {
            token0.safeTransferFrom(msg.sender, address(this), amount0);
        }
        if (amount1 > 0) {
            token1.safeTransferFrom(msg.sender, address(this), amount1);
        }

        // deposit as much new liquidity as possible
        liquidityMinted = LiquidityAmounts.getLiquidityForAmounts(
            sqrtRatioX96,
            lowerTick.getSqrtRatioAtTick(),
            upperTick.getSqrtRatioAtTick(),
            token0.balanceOf(address(this)) - managerBalance0 - gelatoBalance0,
            token1.balanceOf(address(this)) - managerBalance1 - gelatoBalance1
        );
        pool.mint(address(this), lowerTick, upperTick, liquidityMinted, "");

        _mint(receiver, mintAmount);
        emit Minted(receiver, mintAmount, amount0, amount1, liquidityMinted);
    }

    // solhint-disable-next-line function-max-lines
    function burn(uint256 burnAmount, address receiver)
        external
        nonReentrant
        returns (
            uint256 amount0,
            uint256 amount1,
            uint128 liquidityBurned
        )
    {
        require(burnAmount > 0, "burn 0");

        uint256 totalSupply = totalSupply();

        (uint128 liquidity, , , , ) = pool.positions(_getPositionID());

        _burn(msg.sender, burnAmount);

        uint256 _liquidityBurned_ =
            FullMath.mulDiv(burnAmount, liquidity, totalSupply);
        require(_liquidityBurned_ < type(uint128).max);
        liquidityBurned = uint128(_liquidityBurned_);

        uint256 preBalance0 = token0.balanceOf(address(this));
        uint256 preBalance1 = token1.balanceOf(address(this));
        uint256 leftoverShare0 =
            FullMath.mulDiv(
                burnAmount,
                preBalance0 - managerBalance0 - gelatoBalance0,
                totalSupply
            );
        uint256 leftoverShare1 =
            FullMath.mulDiv(
                burnAmount,
                preBalance1 - managerBalance1 - gelatoBalance1,
                totalSupply
            );

        _withdrawExact(
            lowerTick,
            upperTick,
            burnAmount,
            totalSupply,
            liquidityBurned
        );

        amount0 =
            (token0.balanceOf(address(this)) - preBalance0) +
            leftoverShare0;
        amount1 =
            (token1.balanceOf(address(this)) - preBalance1) +
            leftoverShare1;

        if (amount0 > 0) {
            token0.safeTransfer(receiver, amount0);
        }

        if (amount1 > 0) {
            token1.safeTransfer(receiver, amount1);
        }

        emit Burned(receiver, burnAmount, amount0, amount1, liquidityBurned);
    }

    // Manager Functions => Called by Pool Manager

    function executiveRebalance(
        int24 newLowerTick,
        int24 newUpperTick,
        uint160 swapThresholdPrice,
        uint256 swapAmountBPS
    ) external onlyManager {
        (uint128 _liquidity, , , , ) = pool.positions(_getPositionID());
        (uint256 feesEarned0, uint256 feesEarned1) =
            _withdrawAll(lowerTick, upperTick, _liquidity);

        managerBalance0 += (feesEarned0 * managerFeeBPS) / 10000;
        managerBalance1 += (feesEarned1 * managerFeeBPS) / 10000;
        gelatoBalance0 += (feesEarned0 * gelatoFeeBPS) / 10000;
        gelatoBalance1 += (feesEarned1 * gelatoFeeBPS) / 10000;

        lowerTick = newLowerTick;
        upperTick = newUpperTick;

        uint256 reinvest0 =
            token0.balanceOf(address(this)) - managerBalance0 - gelatoBalance0;
        uint256 reinvest1 =
            token1.balanceOf(address(this)) - managerBalance1 - gelatoBalance1;

        _deposit(
            newLowerTick,
            newUpperTick,
            reinvest0,
            reinvest1,
            swapThresholdPrice,
            swapAmountBPS,
            false
        );

        emit Rebalance(newLowerTick, newUpperTick);
    }

    // Gelatofied functions => Automatically called by Gelato

    function rebalance(
        uint160 swapThresholdPrice,
        uint256 swapAmountBPS,
        uint256 feeAmount,
        address paymentToken
    ) external gelatofy(feeAmount, paymentToken) {
        _rebalance(swapThresholdPrice, swapAmountBPS, feeAmount, paymentToken);

        emit Rebalance(lowerTick, upperTick);
    }

    function withdrawManagerBalance(uint256 feeAmount, address feeToken)
        external
        gelatofy(feeAmount, feeToken)
    {
        (uint256 amount0, uint256 amount1) =
            _balancesToWithdraw(
                managerBalance0,
                managerBalance1,
                feeAmount,
                feeToken
            );

        managerBalance0 = 0;
        managerBalance1 = 0;

        if (amount0 > 0) {
            token0.safeTransfer(managerTreasury, amount0);
        }

        if (amount1 > 0) {
            token1.safeTransfer(managerTreasury, amount1);
        }
    }

    function withdrawGelatoBalance(uint256 feeAmount, address feeToken)
        external
        gelatofy(feeAmount, feeToken)
    {
        (uint256 amount0, uint256 amount1) =
            _balancesToWithdraw(
                gelatoBalance0,
                gelatoBalance1,
                feeAmount,
                feeToken
            );

        gelatoBalance0 = 0;
        gelatoBalance1 = 0;

        if (amount0 > 0) {
            token0.safeTransfer(GELATO, amount0);
        }

        if (amount1 > 0) {
            token1.safeTransfer(GELATO, amount1);
        }
    }

    function _balancesToWithdraw(
        uint256 balance0,
        uint256 balance1,
        uint256 feeAmount,
        address feeToken
    ) internal view returns (uint256 amount0, uint256 amount1) {
        if (feeToken == address(token0)) {
            require(
                (balance0 * gelatoWithdrawBPS) / 10000 >= feeAmount,
                "high fee"
            );
            amount0 = balance0 - feeAmount;
            amount1 = balance1;
        } else if (feeToken == address(token1)) {
            require(
                (balance1 * gelatoWithdrawBPS) / 10000 >= feeAmount,
                "high fee"
            );
            amount1 = balance1 - feeAmount;
            amount0 = balance0;
        } else {
            revert("wrong token");
        }
    }

    // View functions

    function getMintAmounts(uint256 amount0Max, uint256 amount1Max)
        external
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 mintAmount
        )
    {
        uint256 totalSupply = totalSupply();
        if (totalSupply > 0) {
            (amount0, amount1, mintAmount) = _computeMintAmounts(
                totalSupply,
                amount0Max,
                amount1Max
            );
        } else {
            (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
            uint128 newLiquidity =
                LiquidityAmounts.getLiquidityForAmounts(
                    sqrtRatioX96,
                    lowerTick.getSqrtRatioAtTick(),
                    upperTick.getSqrtRatioAtTick(),
                    amount0Max,
                    amount1Max
                );
            mintAmount = uint256(newLiquidity);
            (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                lowerTick.getSqrtRatioAtTick(),
                upperTick.getSqrtRatioAtTick(),
                newLiquidity
            );
        }
    }

    // solhint-disable-next-line function-max-lines
    function getUnderlyingBalances()
        public
        view
        returns (uint256 amount0Current, uint256 amount1Current)
    {
        (
            uint128 _liquidity,
            uint256 feeGrowthInside0Last,
            uint256 feeGrowthInside1Last,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = pool.positions(_getPositionID());

        (uint160 sqrtRatioX96, int24 tick, , , , , ) = pool.slot0();

        // compute current holdings from liquidity
        (amount0Current, amount1Current) = LiquidityAmounts
            .getAmountsForLiquidity(
            sqrtRatioX96,
            lowerTick.getSqrtRatioAtTick(),
            upperTick.getSqrtRatioAtTick(),
            _liquidity
        );

        // compute current fees earned
        uint256 fee0 =
            _computeFeesEarned(true, feeGrowthInside0Last, tick, _liquidity);
        uint256 fee1 =
            _computeFeesEarned(false, feeGrowthInside1Last, tick, _liquidity);

        // add any leftover in contract to current holdings
        amount0Current +=
            fee0 +
            uint256(tokensOwed0) +
            token0.balanceOf(address(this)) -
            managerBalance0 -
            gelatoBalance0;
        amount1Current +=
            fee1 +
            uint256(tokensOwed1) +
            token1.balanceOf(address(this)) -
            managerBalance1 -
            gelatoBalance1;
    }

    // Private functions

    // solhint-disable-next-line function-max-lines
    function _rebalance(
        uint160 swapThresholdPrice,
        uint256 swapAmountBPS,
        uint256 feeAmount,
        address paymentToken
    ) private {
        (uint128 _liquidity, , , , ) = pool.positions(_getPositionID());

        (uint256 feesEarned0, uint256 feesEarned1) =
            _withdrawAll(lowerTick, upperTick, _liquidity);

        uint256 reinvest0;
        uint256 reinvest1;
        if (paymentToken == address(token0)) {
            require(
                (feesEarned0 * gelatoRebalanceBPS) / 10000 >= feeAmount,
                "high fee"
            );
            managerBalance0 +=
                ((feesEarned0 - feeAmount) * managerFeeBPS) /
                10000;
            managerBalance1 += (feesEarned1 * managerFeeBPS) / 10000;
            gelatoBalance0 +=
                ((feesEarned0 - feeAmount) * gelatoFeeBPS) /
                10000;
            gelatoBalance1 += (feesEarned1 * gelatoFeeBPS) / 10000;
            reinvest0 =
                token0.balanceOf(address(this)) -
                managerBalance0 -
                gelatoBalance0 -
                feeAmount;
            reinvest1 =
                token1.balanceOf(address(this)) -
                managerBalance1 -
                gelatoBalance1;
        } else if (paymentToken == address(token1)) {
            require(
                (feesEarned1 * gelatoRebalanceBPS) / 10000 >= feeAmount,
                "high fee"
            );
            managerBalance0 += (feesEarned0 * managerFeeBPS) / 10000;
            managerBalance1 +=
                ((feesEarned1 - feeAmount) * managerFeeBPS) /
                10000;
            gelatoBalance0 += (feesEarned0 * gelatoFeeBPS) / 10000;
            gelatoBalance1 +=
                ((feesEarned1 - feeAmount) * gelatoFeeBPS) /
                10000;
            reinvest0 =
                token0.balanceOf(address(this)) -
                managerBalance0 -
                gelatoBalance0;
            reinvest1 =
                token1.balanceOf(address(this)) -
                managerBalance1 -
                gelatoBalance1 -
                feeAmount;
        } else {
            revert("wrong token");
        }

        _deposit(
            lowerTick,
            upperTick,
            reinvest0,
            reinvest1,
            swapThresholdPrice,
            swapAmountBPS,
            true
        );
    }

    // solhint-disable-next-line function-max-lines
    function _withdrawAll(
        int24 lowerTick_,
        int24 upperTick_,
        uint128 liquidity
    ) private returns (uint256 amountEarned0, uint256 amountEarned1) {
        uint256 preBalance0 = token0.balanceOf(address(this));
        uint256 preBalance1 = token1.balanceOf(address(this));

        (uint256 amount0Burned, uint256 amount1Burned) =
            pool.burn(lowerTick_, upperTick_, liquidity);

        pool.collect(
            address(this),
            lowerTick_,
            upperTick_,
            type(uint128).max,
            type(uint128).max
        );

        amountEarned0 =
            token0.balanceOf(address(this)) -
            preBalance0 -
            amount0Burned;
        amountEarned1 =
            token1.balanceOf(address(this)) -
            preBalance1 -
            amount1Burned;
    }

    function _withdrawExact(
        int24 lowerTick_,
        int24 upperTick_,
        uint256 burnAmount,
        uint256 supply,
        uint128 liquidityBurned
    ) private {
        (uint256 burn0, uint256 burn1) =
            pool.burn(lowerTick_, upperTick_, liquidityBurned);

        (, , , uint128 tokensOwed0, uint128 tokensOwed1) =
            pool.positions(_getPositionID());

        burn0 += FullMath.mulDiv(
            burnAmount,
            uint256(tokensOwed0) - burn0,
            supply
        );
        burn1 += FullMath.mulDiv(
            burnAmount,
            uint256(tokensOwed1) - burn1,
            supply
        );

        // Withdraw tokens to user
        pool.collect(
            address(this),
            lowerTick_,
            upperTick_,
            uint128(burn0), // cast can't overflow
            uint128(burn1) // cast can't overflow
        );
    }

    // solhint-disable-next-line function-max-lines
    function _deposit(
        int24 lowerTick_,
        int24 upperTick_,
        uint256 amount0,
        uint256 amount1,
        uint160 swapThresholdPrice,
        uint256 swapAmountBPS,
        bool checkSlippage
    ) private {
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        // First, deposit as much as we can
        uint128 baseLiquidity =
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                lowerTick_.getSqrtRatioAtTick(),
                upperTick_.getSqrtRatioAtTick(),
                amount0,
                amount1
            );
        if (baseLiquidity > 0) {
            (uint256 amountDeposited0, uint256 amountDeposited1) =
                pool.mint(
                    address(this),
                    lowerTick_,
                    upperTick_,
                    baseLiquidity,
                    ""
                );

            amount0 -= amountDeposited0;
            amount1 -= amountDeposited1;
        }

        if (amount0 > 0 || amount1 > 0) {
            // We need to swap the leftover so were balanced, then deposit it
            bool zeroForOne = amount0 > amount1;
            if (checkSlippage) {
                _checkSlippage(swapThresholdPrice, zeroForOne);
            }
            int256 swapAmount =
                int256(
                    ((zeroForOne ? amount0 : amount1) * swapAmountBPS) / 10000
                );
            _swapAndDeposit(
                lowerTick_,
                upperTick_,
                amount0,
                amount1,
                swapAmount,
                swapThresholdPrice,
                zeroForOne
            );
        }
    }

    function _swapAndDeposit(
        int24 lowerTick_,
        int24 upperTick_,
        uint256 amount0,
        uint256 amount1,
        int256 swapAmount,
        uint160 swapThresholdPrice,
        bool zeroForOne
    ) private returns (uint256 finalAmount0, uint256 finalAmount1) {
        (int256 amount0Delta, int256 amount1Delta) =
            pool.swap(
                address(this),
                zeroForOne,
                swapAmount,
                swapThresholdPrice,
                ""
            );
        finalAmount0 = uint256(int256(amount0) - amount0Delta);
        finalAmount1 = uint256(int256(amount1) - amount1Delta);

        // Add liquidity a second time
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        uint128 liquidityAfterSwap =
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                lowerTick_.getSqrtRatioAtTick(),
                upperTick_.getSqrtRatioAtTick(),
                finalAmount0,
                finalAmount1
            );
        if (liquidityAfterSwap > 0) {
            pool.mint(
                address(this),
                lowerTick_,
                upperTick_,
                liquidityAfterSwap,
                ""
            );
        }
    }

    // solhint-disable-next-line function-max-lines, code-complexity
    function _computeMintAmounts(
        uint256 totalSupply,
        uint256 amount0Max,
        uint256 amount1Max
    )
        private
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 mintAmount
        )
    {
        (uint256 amount0Current, uint256 amount1Current) =
            getUnderlyingBalances();

        // compute proportional amount of tokens to mint
        if (amount0Current == 0 && amount1Current > 0) {
            mintAmount = FullMath.mulDiv(
                amount1Max,
                totalSupply,
                amount1Current
            );
        } else if (amount1Current == 0 && amount0Current > 0) {
            mintAmount = FullMath.mulDiv(
                amount0Max,
                totalSupply,
                amount0Current
            );
        } else if (amount0Current == 0 && amount1Current == 0) {
            revert("");
        } else {
            // only if both are non-zero
            uint256 amount0Mint =
                FullMath.mulDiv(amount0Max, totalSupply, amount0Current);
            uint256 amount1Mint =
                FullMath.mulDiv(amount1Max, totalSupply, amount1Current);
            require(amount0Mint > 0 && amount1Mint > 0, "mint 0");

            mintAmount = amount0Mint < amount1Mint ? amount0Mint : amount1Mint;
        }

        // compute amounts owed to contract
        amount0 = FullMath.mulDivRoundingUp(
            mintAmount,
            amount0Current,
            totalSupply
        );
        amount1 = FullMath.mulDivRoundingUp(
            mintAmount,
            amount1Current,
            totalSupply
        );
        //require(amount0 <= amount0Max && amount1 <= amount1Max, "overflow");
    }

    // solhint-disable-next-line function-max-lines
    function _computeFeesEarned(
        bool isZero,
        uint256 feeGrowthInsideLast,
        int24 tick,
        uint128 liquidity
    ) private view returns (uint256 fee) {
        uint256 feeGrowthOutsideLower;
        uint256 feeGrowthOutsideUpper;
        uint256 feeGrowthGlobal;
        if (isZero) {
            feeGrowthGlobal = pool.feeGrowthGlobal0X128();
            (, , feeGrowthOutsideLower, , , , , ) = pool.ticks(lowerTick);
            (, , feeGrowthOutsideUpper, , , , , ) = pool.ticks(upperTick);
        } else {
            feeGrowthGlobal = pool.feeGrowthGlobal1X128();
            (, , , feeGrowthOutsideLower, , , , ) = pool.ticks(lowerTick);
            (, , , feeGrowthOutsideUpper, , , , ) = pool.ticks(upperTick);
        }

        unchecked {
            // calculate fee growth below
            uint256 feeGrowthBelow;
            if (tick >= lowerTick) {
                feeGrowthBelow = feeGrowthOutsideLower;
            } else {
                feeGrowthBelow = feeGrowthGlobal - feeGrowthOutsideLower;
            }

            // calculate fee growth above
            uint256 feeGrowthAbove;
            if (tick < upperTick) {
                feeGrowthAbove = feeGrowthOutsideUpper;
            } else {
                feeGrowthAbove = feeGrowthGlobal - feeGrowthOutsideUpper;
            }

            uint256 feeGrowthInside =
                feeGrowthGlobal - feeGrowthBelow - feeGrowthAbove;
            fee = FullMath.mulDiv(
                liquidity,
                feeGrowthInside - feeGrowthInsideLast,
                0x100000000000000000000000000000000
            );
        }
    }

    function _checkSlippage(uint160 swapThresholdPrice, bool zeroForOne)
        private
        view
    {
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = gelatoSlippageInterval;
        secondsAgo[1] = 0;

        (int56[] memory tickCumulatives, ) = pool.observe(secondsAgo);

        require(tickCumulatives.length == 2, "array length");
        uint160 avgSqrtRatioX96;
        unchecked {
            int24 avgTick =
                int24(
                    (tickCumulatives[1] - tickCumulatives[0]) /
                        int56(uint56(gelatoSlippageInterval))
                );
            avgSqrtRatioX96 = avgTick.getSqrtRatioAtTick();
        }

        uint160 maxSlippage = (avgSqrtRatioX96 * gelatoSlippageBPS) / 10000;
        if (zeroForOne) {
            require(
                swapThresholdPrice >= avgSqrtRatioX96 - maxSlippage,
                "unacceptable slippage"
            );
        } else {
            require(
                swapThresholdPrice <= avgSqrtRatioX96 + maxSlippage,
                "unacceptable slippage"
            );
        }
    }
}
