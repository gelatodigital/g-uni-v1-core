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

/// @dev DO NOT ADD STATE VARIABLES - APPEND THEM TO GelatoUniV3PoolStorage
/// @dev DO NOT ADD BASE CONTRACTS WITH STATE VARS - APPEND THEM TO GelatoUniV3PoolStorage
contract GUniPoolStatic is
    IUniswapV3MintCallback,
    IUniswapV3SwapCallback,
    GUniPoolStaticStorage
    // XXXX DO NOT ADD FURHTER BASES WITH STATE VARS HERE XXXX
{
    using SafeERC20 for IERC20;
    using TickMath for int24;

    event Minted(
        address receiver,
        uint256 mintAmount,
        uint256 amount0In,
        uint256 amount1In,
        uint128 totalLiquidity
    );

    event Burned(
        address receiver,
        uint256 burnAmount,
        uint256 amount0Out,
        uint256 amount1Out,
        uint128 totalLiquidity
    );

    event Rebalance(int24 lowerTick, int24 upperTick);

    constructor(IUniswapV3Pool _pool, address payable _gelato)
        GUniPoolStaticStorage(_pool, _gelato)
    {} // solhint-disable-line no-empty-blocks

    // solhint-disable-next-line function-max-lines, code-complexity
    function uniswapV3MintCallback(
        uint256 _amount0Owed,
        uint256 _amount1Owed,
        bytes calldata /*_data*/
    ) external override {
        require(msg.sender == address(pool));

        if (_amount0Owed > 0) token0.safeTransfer(msg.sender, _amount0Owed);
        if (_amount1Owed > 0) token1.safeTransfer(msg.sender, _amount1Owed);
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

    // solhint-disable-next-line function-max-lines, code-complexity
    function mint(uint256 mintAmount, address receiver)
        external
        nonReentrant
        returns (
            uint256 amount0,
            uint256 amount1,
            uint128 totalLiquidity
        )
    {
        require(mintAmount > 0, "mint amount must be gt 0");
        uint256 totalSupply = totalSupply();
        require(
            _supplyCap >= totalSupply + mintAmount,
            "cannot mint above supply cap"
        );

        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        if (totalSupply > 0) {
            (uint128 liquidity, , , , ) = pool.positions(_getPositionID());

            pool.burn(_lowerTick, _upperTick, liquidity);

            pool.collect(
                address(this),
                _lowerTick,
                _upperTick,
                type(uint128).max,
                type(uint128).max
            );

            amount0 = FullMath.mulDivRoundingUp(
                token0.balanceOf(address(this)) - _adminBalanaceToken0,
                mintAmount,
                totalSupply
            );
            amount1 = FullMath.mulDivRoundingUp(
                token1.balanceOf(address(this)) - _adminBalanaceToken1,
                mintAmount,
                totalSupply
            );
        } else {
            // if supply is 0 mintAmount == liquidity to deposit
            (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                _lowerTick.getSqrtRatioAtTick(),
                _upperTick.getSqrtRatioAtTick(),
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
            _lowerTick.getSqrtRatioAtTick(),
            _upperTick.getSqrtRatioAtTick(),
            token0.balanceOf(address(this)) - _adminBalanceToken0,
            token1.balanceOf(address(this)) - _adminBalanceToken1
        );
        pool.mint(address(this), _lowerTick, _upperTick, liquidityMinted, "");

        _mint(receiver, mintAmount);
        emit Minted(receiver, mintAmount, amount0, amount1, liquidityMinted);
    }

    // solhint-disable-next-line function-max-lines
    function burn(uint256 _burnAmount, address _receiver)
        external
        nonReentrant
        returns (
            uint256 amount0,
            uint256 amount1,
            uint128 totalLiquidity
        )
    {
        require(_burnAmount > 0);
        uint256 totalSupply = totalSupply();
        _burn(msg.sender, _burnAmount);

        (uint128 liquidity, , , , ) = pool.positions(_getPositionID());

        pool.burn(_lowerTick, _upperTick, liquidity);

        pool.collect(
            address(this),
            _lowerTick,
            _upperTick,
            type(uint128).max,
            type(uint128).max
        );

        amount0 =
            FullMath.mulDiv(
                _burnAmount,
                token0.balanceOf(address(this)) - _adminBalanceToken0,
                totalSupply
            );
        amount1 =
            FullMath.mulDiv(
                _burnAmount,
                token1.balanceOf(address(this)) - _adminBalanceToken1,
                totalSupply
            );

        if (amount0 > 0) {
            token0.safeTransfer(_receiver, amount0);
        }

        if (amount1 > 0) {
            token1.safeTransfer(_receiver, amount1);
        }

        liquidityMinted = LiquidityAmounts.getLiquidityForAmounts(
            sqrtRatioX96,
            _lowerTick.getSqrtRatioAtTick(),
            _upperTick.getSqrtRatioAtTick(),
            token0.balanceOf(address(this)) - _adminBalanceToken0,
            token1.balanceOf(address(this)) - _adminBalanceToken1
        );
        pool.mint(address(this), _lowerTick, _upperTick, liquidityMinted, "");

        emit Burned(_receiver, _burnAmount, amount0, amount1, liquidityBurned);
    }

    function rebalance(
        uint160 _swapThresholdPrice,
        uint256 _swapAmountBPS,
        uint256 _feeAmount,
        address _paymentToken
    ) external gelatofy(_feeAmount, _paymentToken) {
        _reinvestFees(
            _swapThresholdPrice,
            _swapAmountBPS,
            _feeAmount,
            _paymentToken
        );

        emit Rebalance(_lowerTick, _upperTick);
    }

    function executiveRebalance(
        int24 _newLowerTick,
        int24 _newUpperTick,
        uint160 _swapThresholdPrice,
        uint256 _swapAmountBPS
    ) external onlyOwner {
        (uint128 _liquidity, , , , ) = pool.positions(_getPositionID());
        (uint256 feesEarned0, uint256 feesEarned1) =
            _withdraw(_lowerTick, _upperTick, _liquidity);

        _adminBalanceToken0 += (feesEarned0 * _adminFeeBPS) / 10000;
        _adminBalanceToken1 += (feesEarned1 * _adminFeeBPS) / 10000;

        _lowerTick = _newLowerTick;
        _upperTick = _newUpperTick;

        uint256 reinvest0 =
            token0.balanceOf(address(this)) - _adminBalanceToken0;
        uint256 reinvest1 =
            token1.balanceOf(address(this)) - _adminBalanceToken1;

        _deposit(
            _newLowerTick,
            _newUpperTick,
            reinvest0,
            reinvest1,
            _swapThresholdPrice,
            _swapAmountBPS
        );

        emit Rebalance(_newLowerTick, _newUpperTick);
    }

    function withdrawAdminBalance() external nonReentrant {
        if (_adminBalanceToken0 > 0) {
            uint256 amountToSend0 = _adminBalanceToken0;
            _adminBalanceToken0 = 0;
            token0.safeTransfer(_treasury, amountToSend0);
        }
        if (_adminBalanceToken1 > 0) {
            uint256 amountToSend1 = _adminBalanceToken1;
            _adminBalanceToken1 = 0;
            token1.safeTransfer(_treasury, amountToSend1);
        }
    }

    function autoWithdrawAdminBalance(uint256 feeAmount, address feeToken)
        external
        gelatofy(feeAmount, feeToken)
    {
        uint256 amount0;
        uint256 amount1;
        if (feeToken == address(token0)) {
            require(
                (_adminBalanceToken0 * _autoWithdrawFeeBPS) / 10000 >=
                    feeAmount,
                "only withdraw after enough fees accrued"
            );
            amount0 = _adminBalanceToken0 - feeAmount;
            _adminBalanceToken0 = 0;
            amount1 = _adminBalanceToken1;
            _adminBalanceToken1 = 0;
        } else if (feeToken == address(token1)) {
            require(
                (_adminBalanceToken1 * _autoWithdrawFeeBPS) / 10000 >=
                    feeAmount,
                "only withdraw after enough fees accrued"
            );
            amount1 = _adminBalanceToken1 - feeAmount;
            _adminBalanceToken1 = 0;
            amount0 = _adminBalanceToken0;
            _adminBalanceToken0 = 0;
        } else {
            revert("feeToken must be a pool asset");
        }

        if (amount0 > 0) {
            token0.safeTransfer(_treasury, amount0);
        }

        if (amount1 > 0) {
            token1.safeTransfer(_treasury, amount1);
        }
    }

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
        (uint160 sqrtRatioX96, int24 tick, , , , , ) = pool.slot0();
        if (totalSupply > 0) {
            (amount0, amount1, mintAmount) = _computeMintAmounts(
                sqrtRatioX96,
                tick,
                totalSupply,
                amount0Max,
                amount1Max
            );
        } else {
            uint128 newLiquidity =
                LiquidityAmounts.getLiquidityForAmounts(
                    sqrtRatioX96,
                    _lowerTick.getSqrtRatioAtTick(),
                    _upperTick.getSqrtRatioAtTick(),
                    amount0Max,
                    amount1Max
                );
            mintAmount = uint256(newLiquidity);
            (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                _lowerTick.getSqrtRatioAtTick(),
                _upperTick.getSqrtRatioAtTick(),
                newLiquidity
            );
        }
    }

    // solhint-disable-next-line function-max-lines, code-complexity
    function _computeMintAmounts(
        uint160 sqrtRatioX96,
        int24 tick,
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
            _getCurrentAmounts(sqrtRatioX96, tick);

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
            revert("impossible: internal error");
        } else {
            // only if both are non-zero
            uint256 amount0Mint =
                FullMath.mulDiv(amount0Max, totalSupply, amount0Current);
            uint256 amount1Mint =
                FullMath.mulDiv(amount1Max, totalSupply, amount1Current);
            require(amount0Mint > 0 && amount1Mint > 0, "cannot mint 0 tokens");

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

    function _getCurrentAmounts(uint160 sqrtRatioX96, int24 tick)
        internal
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

        // compute current holdings from liquidity
        (amount0Current, amount1Current) = LiquidityAmounts
            .getAmountsForLiquidity(
            sqrtRatioX96,
            _lowerTick.getSqrtRatioAtTick(),
            _upperTick.getSqrtRatioAtTick(),
            _liquidity
        );

        // compute current fees earned
        (uint256 fee0, uint256 fee1) = _getFeeGrowth(
            tick,
            _liquidity,
            feeGrowthInside0Last,
            feeGrowthInside1Last
        );

        // add any leftover in contract to current holdings
        amount0Current +=
            fee0 + uint256(tokensOwed0) + token0.balanceOf(address(this)) -
            _adminBalanceToken0;
        amount1Current +=
            fee1 + uint256(tokensOwed1) + token1.balanceOf(address(this)) -
            _adminBalanceToken1;
    }

    function _getFeeGrowth(
        int24 tick,
        uint128 _liquidity,
        uint256 feeGrowthInside0Last,
        uint256 feeGrowthInside1Last
    )
        internal
        view
        returns (uint256 fee0, uint256 fee1)
    {
        uint256 feeGrowthGlobal0 = pool.feeGrowthGlobal0X128();
        uint256 feeGrowthGlobal1 = pool.feeGrowthGlobal1X128();
        (,,uint256 feeGrowthOutside0Lower, uint256 feeGrowthOutside1Lower,,,,) =
            pool.ticks(_lowerTick);
        (,,uint256 feeGrowthOutside0Upper, uint256 feeGrowthOutside1Upper,,,,) =
            pool.ticks(_lowerTick);
        fee0 = _computeFeeGrowth(
            feeGrowthGlobal0,
            feeGrowthOutside0Lower,
            feeGrowthOutside0Upper,
            feeGrowthInside0Last,
            tick,
            _liquidity
        );
        fee1 = _computeFeeGrowth(
            feeGrowthGlobal1,
            feeGrowthOutside1Lower,
            feeGrowthOutside1Upper,
            feeGrowthInside1Last,
            tick,
            _liquidity
        );
    }

    function _computeFeeGrowth(
        uint256 feeGrowthGlobal,
        uint256 feeGrowthOutsideLower,
        uint256 feeGrowthOutsideUpper,
        uint256 feeGrowthInsideLast,
        int24 tick,
        uint128 _liquidity
    )
        internal
        view
        returns (uint256 fee)
    {
        // TODO: off-chain logic
    }

    // solhint-disable-next-line function-max-lines
    function _reinvestFees(
        uint160 _swapThresholdPrice,
        uint256 _swapAmountBPS,
        uint256 _feeAmount,
        address _paymentToken
    ) private {
        (uint128 _liquidity, , , , ) = pool.positions(_getPositionID());

        (uint256 feesEarned0, uint256 feesEarned1) =
            _withdraw(_lowerTick, _upperTick, _liquidity);

        uint256 reinvest0;
        uint256 reinvest1;
        if (_paymentToken == address(token0)) {
            require(
                (feesEarned0 * _rebalanceFeeBPS) / 10000 >= _feeAmount,
                "must earn more fees before rebalance"
            );
            _adminBalanceToken0 +=
                ((feesEarned0 - _feeAmount) * _adminFeeBPS) /
                10000;
            _adminBalanceToken1 += (feesEarned1 * _adminFeeBPS) / 10000;
            reinvest0 =
                token0.balanceOf(address(this)) -
                _adminBalanceToken0 -
                _feeAmount;
            reinvest1 = token1.balanceOf(address(this)) - _adminBalanceToken1;
        } else if (_paymentToken == address(token1)) {
            require(
                (feesEarned1 * _rebalanceFeeBPS) / 10000 >= _feeAmount,
                "must earn more fees before rebalance"
            );
            _adminBalanceToken0 += (feesEarned0 * _adminFeeBPS) / 10000;
            _adminBalanceToken1 +=
                ((feesEarned1 - _feeAmount) * _adminFeeBPS) /
                10000;
            reinvest0 = token0.balanceOf(address(this)) - _adminBalanceToken0;
            reinvest1 =
                token1.balanceOf(address(this)) -
                _adminBalanceToken1 -
                _feeAmount;
        } else {
            revert("fee token must be one of the pool assets");
        }

        _deposit(
            _lowerTick,
            _upperTick,
            reinvest0,
            reinvest1,
            _swapThresholdPrice,
            _swapAmountBPS
        );
    }

    // solhint-disable-next-line function-max-lines
    function _withdraw(
        int24 _lowerTick,
        int24 _upperTick,
        uint128 _liquidity
    ) private returns (uint256 amountEarned0, uint256 amountEarned1) {
        uint256 preBalance0 = token0.balanceOf(address(this));
        uint256 preBalance1 = token1.balanceOf(address(this));

        (uint256 amount0Burned, uint256 amount1Burned) =
            pool.burn(_lowerTick, _upperTick, _liquidity);

        pool.collect(
            address(this),
            _lowerTick,
            _upperTick,
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

    // solhint-disable-next-line function-max-lines
    function _deposit(
        int24 _lowerTick,
        int24 _upperTick,
        uint256 _amount0,
        uint256 _amount1,
        uint160 _swapThresholdPrice,
        uint256 _swapAmountBPS
    ) private {
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        // First, deposit as much as we can
        uint128 baseLiquidity =
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                _lowerTick.getSqrtRatioAtTick(),
                _upperTick.getSqrtRatioAtTick(),
                _amount0,
                _amount1
            );
        if (baseLiquidity > 0) {
            (uint256 amountDeposited0, uint256 amountDeposited1) =
                pool.mint(
                    address(this),
                    _lowerTick,
                    _upperTick,
                    baseLiquidity,
                    ""
                );

            _amount0 -= amountDeposited0;
            _amount1 -= amountDeposited1;
        }

        if (_amount0 > 0 || _amount1 > 0) {
            // We need to swap the leftover so were balanced, then deposit it
            bool zeroForOne = _amount0 > _amount1;
            _checkSlippage(_swapThresholdPrice, zeroForOne);
            int256 swapAmount =
                int256(
                    ((zeroForOne ? _amount0 : _amount1) * _swapAmountBPS) /
                        10000
                );
            (_amount0, _amount1) = _swapAndDeposit(
                _lowerTick,
                _upperTick,
                _amount0,
                _amount1,
                swapAmount,
                _swapThresholdPrice,
                zeroForOne
            );
        }
    }

    function _swapAndDeposit(
        int24 _lowerTick,
        int24 _upperTick,
        uint256 _amount0,
        uint256 _amount1,
        int256 _swapAmount,
        uint160 _swapThresholdPrice,
        bool _zeroForOne
    ) private returns (uint256 finalAmount0, uint256 finalAmount1) {
        (int256 amount0Delta, int256 amount1Delta) =
            pool.swap(
                address(this),
                _zeroForOne,
                _swapAmount,
                _swapThresholdPrice,
                ""
            );
        finalAmount0 = uint256(int256(_amount0) - amount0Delta);
        finalAmount1 = uint256(int256(_amount1) - amount1Delta);

        // Add liquidity a second time
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        uint128 liquidityAfterSwap =
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(_lowerTick),
                TickMath.getSqrtRatioAtTick(_upperTick),
                finalAmount0,
                finalAmount1
            );
        if (liquidityAfterSwap > 0) {
            pool.mint(
                address(this),
                _lowerTick,
                _upperTick,
                liquidityAfterSwap,
                ""
            );
        }
    }

    function _checkSlippage(uint160 _swapThresholdPrice, bool zeroForOne)
        private
        view
    {
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = _observationSeconds;
        secondsAgo[1] = 0;

        (int56[] memory tickCumulatives, ) = pool.observe(secondsAgo);

        require(tickCumulatives.length == 2, "unexpected length of tick array");

        int24 avgTick =
            int24(
                (tickCumulatives[1] - tickCumulatives[0]) /
                    int56(uint56(_observationSeconds))
            );
        uint160 avgSqrtRatioX96 = avgTick.getSqrtRatioAtTick();

        uint160 maxSlippage = (avgSqrtRatioX96 * _maxSlippageBPS) / 10000;
        if (zeroForOne) {
            require(
                _swapThresholdPrice >= avgSqrtRatioX96 - maxSlippage,
                "slippage price is out of acceptable range"
            );
        } else {
            require(
                _swapThresholdPrice <= avgSqrtRatioX96 + maxSlippage,
                "slippage price is out of acceptable range"
            );
        }
    }
}
