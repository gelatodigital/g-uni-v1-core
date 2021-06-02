// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import {
    IUniswapV3MintCallback
} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3SwapCallback
} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {GelatoUniV3PoolStorage} from "./abstract/GelatoUniV3PoolStorage.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "./vendor/uniswap/TickMath.sol";
import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LiquidityAmounts} from "./vendor/uniswap/LiquidityAmounts.sol";

/// @dev DO NOT ADD STATE VARIABLES - APPEND THEM TO GelatoUniV3PoolStorage
/// @dev DO NOT ADD BASE CONTRACTS WITH STATE VARS - APPEND THEM TO GelatoUniV3PoolStorage
contract GelatoUniV3Pool is
    IUniswapV3MintCallback,
    IUniswapV3SwapCallback,
    GelatoUniV3PoolStorage
    // XXXX DO NOT ADD FURHTER BASES WITH STATE VARS HERE XXXX
{
    using SafeERC20 for IERC20;
    using TickMath for int24;

    event Minted(
        address minter,
        uint256 mintAmount,
        uint256 amount0In,
        uint256 amount1In
    );

    event Burned(
        address burner,
        uint256 burnAmount,
        uint256 amount0Out,
        uint256 amount1Out
    );

    event Rebalance(int24 newLowerTick, int24 newUpperTick);

    constructor(IUniswapV3Pool _pool, address payable _gelato)
        GelatoUniV3PoolStorage(_pool, _gelato)
    {} // solhint-disable-line no-empty-blocks

    // solhint-disable-next-line function-max-lines, code-complexity
    function uniswapV3MintCallback(
        uint256 _amount0Owed,
        uint256 _amount1Owed,
        bytes calldata _data
    ) external override {
        require(msg.sender == address(pool));

        address sender = abi.decode(_data, (address));

        if (sender == address(this)) {
            if (_amount0Owed > 0) token0.safeTransfer(msg.sender, _amount0Owed);
            if (_amount1Owed > 0) token1.safeTransfer(msg.sender, _amount1Owed);
        } else {
            if (_amount0Owed > 0)
                token0.safeTransferFrom(sender, msg.sender, _amount0Owed);
            if (_amount1Owed > 0)
                token1.safeTransferFrom(sender, msg.sender, _amount1Owed);
        }
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
    function mint(uint256 amount0Max, uint256 amount1Max)
        external
        nonReentrant
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 mintAmount
        )
    {
        uint256 totalSupply = totalSupply();
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        if (totalSupply > 0) {
            (amount0, amount1, mintAmount) = _computeMintAmounts(
                sqrtRatioX96,
                totalSupply,
                amount0Max,
                amount1Max
            );

            // transfer amounts owed to contract
            if (amount0 > 0) {
                token0.safeTransferFrom(msg.sender, address(this), amount0);
            }
            if (amount1 > 0) {
                token1.safeTransferFrom(msg.sender, address(this), amount1);
            }

            // deposit as much new liquidity as possible
            uint128 newLiquidity =
                LiquidityAmounts.getLiquidityForAmounts(
                    sqrtRatioX96,
                    _currentLowerTick.getSqrtRatioAtTick(),
                    _currentUpperTick.getSqrtRatioAtTick(),
                    token0.balanceOf(address(this)),
                    token1.balanceOf(address(this))
                );
            pool.mint(
                address(this),
                _currentLowerTick,
                _currentUpperTick,
                newLiquidity,
                abi.encode(address(this))
            );
        } else {
            // if very first mint, tokens out = liquidity provided
            uint128 newLiquidity =
                LiquidityAmounts.getLiquidityForAmounts(
                    sqrtRatioX96,
                    _currentLowerTick.getSqrtRatioAtTick(),
                    _currentUpperTick.getSqrtRatioAtTick(),
                    amount0Max,
                    amount1Max
                );
            mintAmount = uint256(newLiquidity);
            (amount0, amount1) = pool.mint(
                address(this),
                _currentLowerTick,
                _currentUpperTick,
                newLiquidity,
                abi.encode(msg.sender)
            );
        }

        require(mintAmount > 0, "mint amount must be gt 0");

        require(
            _supplyCap >= totalSupply + mintAmount,
            "GelatoUniV3Pool.mint: _supplyCap"
        );

        _mint(msg.sender, mintAmount);
        emit Minted(msg.sender, mintAmount, amount0, amount1);
    }

    // solhint-disable-next-line function-max-lines
    function burn(uint256 _burnAmount)
        external
        nonReentrant
        returns (
            uint256 amount0,
            uint256 amount1,
            uint128 liquidityBurned
        )
    {
        require(_burnAmount > 0);

        uint256 totalSupply = totalSupply();

        (uint128 liquidity, , , , ) = pool.positions(_getPositionID());

        _burn(msg.sender, _burnAmount);

        uint256 _liquidityBurned_ = (_burnAmount * liquidity) / totalSupply;
        require(_liquidityBurned_ < type(uint128).max);
        liquidityBurned = uint128(_liquidityBurned_);

        (amount0, amount1) = pool.burn(
            _currentLowerTick,
            _currentUpperTick,
            liquidityBurned
        );
        uint256 leftover0 =
            token0.balanceOf(address(this)) - _adminBalanceToken0;
        uint256 leftover1 =
            token1.balanceOf(address(this)) - _adminBalanceToken1;
        uint256 leftoverShare0 = (_burnAmount * leftover0) / totalSupply;
        uint256 leftoverShare1 = (_burnAmount * leftover1) / totalSupply;

        // Withdraw tokens to user
        pool.collect(
            address(this),
            _currentLowerTick,
            _currentUpperTick,
            uint128(amount0), // cast can't overflow
            uint128(amount1) // cast can't overflow
        );

        amount0 += leftoverShare0;
        amount1 += leftoverShare1;

        if (amount0 > 0) {
            token0.safeTransfer(msg.sender, amount0);
        }

        if (amount1 > 0) {
            token1.safeTransfer(msg.sender, amount1);
        }

        emit Burned(msg.sender, _burnAmount, amount0, amount1);
    }

    function rebalance(
        int24 _newLowerTick,
        int24 _newUpperTick,
        uint160 _swapThresholdPrice,
        uint256 _swapAmountBPS,
        uint256 _feeAmount,
        address _paymentToken
    ) external gelatofy(_feeAmount, _paymentToken) {
        _adjustCurrentPool(
            _newLowerTick,
            _newUpperTick,
            _swapThresholdPrice,
            _swapAmountBPS,
            _feeAmount,
            _paymentToken
        );

        // solhint-disable-next-line not-rely-on-time
        _lastRebalanceTimestamp = block.timestamp;

        emit Rebalance(_newLowerTick, _newUpperTick);
    }

    function withdrawFromAdminBalance(uint256 amountOut, address token)
        external
        nonReentrant
    {
        require(
            owner() == msg.sender || _adminWhitelistedTreasury[msg.sender],
            "not authorized to withdraw admin fees"
        );
        if (address(token0) == token) {
            _adminBalanceToken0 -= amountOut;
            token0.safeTransfer(msg.sender, amountOut);
        } else if (address(token1) == token) {
            _adminBalanceToken1 -= amountOut;
            token1.safeTransfer(msg.sender, amountOut);
        }
    }

    function autoWithdrawFromAdminBalance(
        uint256 amountOut,
        address token,
        address receiver,
        uint256 feeAmount
    ) external gelatofy(feeAmount, token) {
        require(
            (amountOut * _maxWithdrawFeeBPS) / 10000 >= feeAmount,
            "withrdrawal cannot be too small"
        );
        require(
            receiver == owner() || _adminWhitelistedTreasury[receiver],
            "only admins may receive withdrawal"
        );
        if (token == address(token0)) {
            _adminBalanceToken0 -= amountOut + feeAmount;
            token0.safeTransfer(receiver, amountOut);
        } else if (token == address(token1)) {
            _adminBalanceToken1 -= amountOut + feeAmount;
            token1.safeTransfer(receiver, amountOut);
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
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        if (totalSupply > 0) {
            (amount0, amount1, mintAmount) = _computeMintAmounts(
                sqrtRatioX96,
                totalSupply,
                amount0Max,
                amount1Max
            );
        } else {
            uint128 newLiquidity =
                LiquidityAmounts.getLiquidityForAmounts(
                    sqrtRatioX96,
                    _currentLowerTick.getSqrtRatioAtTick(),
                    _currentUpperTick.getSqrtRatioAtTick(),
                    amount0Max,
                    amount1Max
                );
            mintAmount = uint256(newLiquidity);
            (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                _currentLowerTick.getSqrtRatioAtTick(),
                _currentUpperTick.getSqrtRatioAtTick(),
                newLiquidity
            );
        }
    }

    // solhint-disable-next-line function-max-lines
    function _computeMintAmounts(
        uint160 sqrtRatioX96,
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
        (uint128 _liquidity, , , , ) = pool.positions(_getPositionID());

        // compute current holdings from liquidity
        (uint256 amount0Current, uint256 amount1Current) =
            LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                _currentLowerTick.getSqrtRatioAtTick(),
                _currentUpperTick.getSqrtRatioAtTick(),
                _liquidity
            );

        // add any leftover in contract to current holdings
        amount0Current =
            amount0Current +
            token0.balanceOf(address(this)) -
            _adminBalanceToken0;
        amount1Current =
            amount1Current +
            token1.balanceOf(address(this)) -
            _adminBalanceToken1;

        // compute proportional amount of tokens to mint
        if (amount0Current == 0 && amount1Current > 0) {
            mintAmount = (amount1Max * totalSupply) / amount1Current;
        } else if (amount1Current == 0 && amount0Current > 0) {
            mintAmount = (amount0Max * totalSupply) / amount0Current;
        } else {
            uint256 amount0Mint =
                amount0Current > 0
                    ? (amount0Max * totalSupply) / amount0Current
                    : 0;
            uint256 amount1Mint =
                amount1Current > 0
                    ? (amount1Max * totalSupply) / amount1Current
                    : 0;
            mintAmount = amount0Mint < amount1Mint ? amount0Mint : amount1Mint;
        }

        // compute amounts owed to contract
        amount0 = (mintAmount * amount0Current) / totalSupply;
        amount1 = (mintAmount * amount1Current) / totalSupply;
    }

    // solhint-disable-next-line function-max-lines
    function _adjustCurrentPool(
        int24 _newLowerTick,
        int24 _newUpperTick,
        uint160 _swapThresholdPrice,
        uint256 _swapAmountBPS,
        uint256 _feeAmount,
        address _paymentToken
    ) private {
        uint256 reinvest0;
        uint256 reinvest1;
        {
            (uint128 _liquidity, , , , ) = pool.positions(_getPositionID());

            (uint256 adminFee0, uint256 adminFee1) =
                _withdraw(
                    _currentLowerTick,
                    _currentUpperTick,
                    _liquidity,
                    _feeAmount,
                    _paymentToken,
                    _disableChangeTicks
                );

            reinvest0 = _paymentToken == address(token0)
                ? token0.balanceOf(address(this)) - adminFee0 - _feeAmount
                : token0.balanceOf(address(this)) - adminFee0;

            reinvest1 = _paymentToken == address(token1)
                ? token1.balanceOf(address(this)) - adminFee1 - _feeAmount
                : token1.balanceOf(address(this)) - adminFee1;
        }

        // if changing ticks on rebalance is disabled, simply redeposit around current ticks
        if (_disableChangeTicks) {
            _deposit(
                _currentLowerTick,
                _currentUpperTick,
                reinvest0,
                reinvest1,
                _swapThresholdPrice,
                _swapAmountBPS
            );
        } else {
            (, int24 midTick, , , , , ) = pool.slot0();

            // solhint-disable-next-line not-rely-on-time
            if (block.timestamp < _lastRebalanceTimestamp + _heartbeat) {
                require(
                    midTick > _currentUpperTick || midTick < _currentLowerTick,
                    "GelatoUniV3Pool._adjustCurrentPool: price still in range and no heartbeat"
                );
            }

            require(
                _newLowerTick <= midTick - _minTickDeviation &&
                    _newLowerTick >= midTick - _maxTickDeviation,
                "GelatoUniV3Pool._adjustCurrentPool: lowerTick out of range"
            );

            require(
                _newUpperTick <= midTick + _maxTickDeviation &&
                    _newUpperTick >= midTick + _minTickDeviation,
                "GelatoUniV3Pool._adjustCurrentPool: upperTick out of range"
            );

            if (_currentLowerTick != _newLowerTick)
                _currentLowerTick = _newLowerTick;
            if (_currentUpperTick != _newUpperTick)
                _currentUpperTick = _newUpperTick;
            _deposit(
                _newLowerTick,
                _newUpperTick,
                reinvest0,
                reinvest1,
                _swapThresholdPrice,
                _swapAmountBPS
            );
        }
    }

    // solhint-disable-next-line function-max-lines
    function _withdraw(
        int24 _lowerTick,
        int24 _upperTick,
        uint128 _liquidity,
        uint256 _feeAmount,
        address _paymentToken,
        bool _checkRebalanceFee
    ) private returns (uint256 adminFee0, uint256 adminFee1) {
        (uint256 amount0Burned, uint256 amount1Burned) =
            pool.burn(_lowerTick, _upperTick, _liquidity);
        (uint256 amount0Total, uint256 amount1Total) =
            pool.collect(
                address(this),
                _lowerTick,
                _upperTick,
                type(uint128).max,
                type(uint128).max
            );
        uint256 amountFeesAccrued0 = amount0Total - amount0Burned;
        uint256 amountFeesAccrued1 = amount1Total - amount1Burned;

        // require fees accrued to be X times greater than the transaction fee of rebalancing
        if (_checkRebalanceFee) {
            if (_paymentToken == address(token0)) {
                require(
                    (amountFeesAccrued0 * _maxRebalanceFeeBPS) / 10000 >=
                        _feeAmount,
                    "cannot rebalance: tx fee is too large for fee reinvestment"
                );
            } else {
                require(
                    (amountFeesAccrued1 * _maxRebalanceFeeBPS) / 10000 >=
                        _feeAmount,
                    "cannot rebalance: tx fee is too large for fee reinvestment"
                );
            }
        }

        adminFee0 = (amountFeesAccrued0 * _adminFeeBPS) / 10000;
        adminFee1 = (amountFeesAccrued1 * _adminFeeBPS) / 10000;

        _adminBalanceToken0 += adminFee0;
        _adminBalanceToken1 += adminFee1;
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

        if (_amount0 > 0 && _amount1 > 0) {
            // First, deposit as much as we can
            uint128 baseLiquidity =
                LiquidityAmounts.getLiquidityForAmounts(
                    sqrtRatioX96,
                    _lowerTick.getSqrtRatioAtTick(),
                    _upperTick.getSqrtRatioAtTick(),
                    _amount0,
                    _amount1
                );

            (uint256 amountDeposited0, uint256 amountDeposited1) =
                pool.mint(
                    address(this),
                    _lowerTick,
                    _upperTick,
                    baseLiquidity,
                    abi.encode(address(this))
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

        pool.mint(
            address(this),
            _lowerTick,
            _upperTick,
            liquidityAfterSwap,
            abi.encode(address(this))
        );
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

        uint160 maxSlippage = (avgSqrtRatioX96 * _maxSlippagePercentage) / 100;
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
