//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {
    IUniswapV3MintCallback
} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3SwapCallback
} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol";

import "@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol";

import {TransferHelper} from "./libraries/TransferHelper.sol";
import {LiquidityAmounts} from "./libraries/LiquidityAmounts.sol";
import {ERC20} from "./ERC20.sol";
import {Gelatofied} from "./Gelatofied.sol";
import {ReentrancyGuard} from "./ReentrancyGuard.sol";
import {Ownable} from "./Ownable.sol";

contract MetaPool is
    IUniswapV3MintCallback,
    IUniswapV3SwapCallback,
    ERC20,
    Gelatofied,
    ReentrancyGuard,
    Ownable
{
    using LowGasSafeMath for uint256;

    int24 public currentLowerTick;
    int24 public currentUpperTick;

    IUniswapV3Pool public immutable pool;
    IERC20Minimal public immutable token0;
    IERC20Minimal public immutable token1;

    address public immutable gelato;

    int24 private constant MIN_TICK = -887220;
    int24 private constant MAX_TICK = 887220;

    uint256 public lastRebalanceTimestamp;

    uint256 public supplyCap = 20000 * 10**18; // default: 20,000 gUNIV3
    uint256 public heartbeat = 86400; // default: one day
    int24 public minTickDeviation = 120; // default: ~1% price difference up and down
    int24 public maxTickDeviation = 7000; // default: ~100% price difference up and down
    uint32 public observationSeconds = 300; // default: last five minutes;
    uint160 public maxSlippagePercentage = 5; //default: 5% slippage

    event ParamsAdjusted(int24 newLowerTick, int24 newUpperTick);

    event MetaParamsAdjusted(
        uint256 supplyCap,
        uint256 heartbeat,
        int24 minTickDeviation,
        int24 maxTickDeviation,
        uint32 observationSeconds,
        uint160 maxSlippagePercentage
    );

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

    constructor(
        string memory _name,
        IUniswapV3Pool _pool,
        int24 _initialLowerTick,
        int24 _initialUpperTick,
        address _gelato
    ) ERC20(_name) {
        pool = _pool;
        token0 = IERC20Minimal(_pool.token0());
        token1 = IERC20Minimal(_pool.token1());

        currentLowerTick = _initialLowerTick;
        currentUpperTick = _initialUpperTick;

        gelato = _gelato;
    }

    function mint(uint128 newLiquidity) external returns (uint256 mintAmount) {
        require(newLiquidity > 0);

        (uint128 _liquidity, , , , ) = pool.positions(_getPositionID());

        if (totalSupply == 0) {
            mintAmount = newLiquidity;
        } else {
            mintAmount = uint256(newLiquidity).mul(totalSupply) / _liquidity;
        }
        require(
            supplyCap >= totalSupply.add(mintAmount),
            "cannot mint more than supplyCap"
        );

        // proportionally add to any uninvested capital as well
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 extraAmount0;
        if (balance0 > 0) {
            extraAmount0 = uint256(newLiquidity).mul(balance0) / _liquidity;
        }
        if (extraAmount0 > 0) {
            TransferHelper.safeTransferFrom(
                address(token0),
                msg.sender,
                address(this),
                extraAmount0
            );
        }

        uint256 balance1 = token1.balanceOf(address(this));
        uint256 extraAmount1;
        if (balance1 > 0) {
            extraAmount1 = uint256(newLiquidity).mul(balance1) / _liquidity;
        }
        if (extraAmount1 > 0) {
            TransferHelper.safeTransferFrom(
                address(token1),
                msg.sender,
                address(this),
                extraAmount1
            );
        }

        (uint256 amount0, uint256 amount1) =
            pool.mint(
                address(this),
                currentLowerTick,
                currentUpperTick,
                newLiquidity,
                abi.encode(msg.sender)
            );

        _mint(msg.sender, mintAmount);
        emit Minted(
            msg.sender,
            mintAmount,
            amount0.add(extraAmount0),
            amount1.add(extraAmount1)
        );
    }

    function burn(uint256 burnAmount)
        external
        nonReentrant
        returns (
            uint256 amount0,
            uint256 amount1,
            uint128 liquidityBurned
        )
    {
        require(burnAmount > 0);
        uint256 _totalSupply = totalSupply;

        (uint128 _liquidity, , , , ) = pool.positions(_getPositionID());

        _burn(msg.sender, burnAmount);

        uint256 _liquidityBurned = burnAmount.mul(_liquidity) / _totalSupply;
        require(_liquidityBurned < type(uint128).max);
        liquidityBurned = uint128(_liquidityBurned);

        (amount0, amount1) = pool.burn(
            currentLowerTick,
            currentUpperTick,
            liquidityBurned
        );

        // Withdraw tokens to user
        pool.collect(
            msg.sender,
            currentLowerTick,
            currentUpperTick,
            uint128(amount0), // cast can't overflow
            uint128(amount1) // cast can't overflow
        );

        uint256 extraAmount0 =
            uint256(burnAmount).mul(token0.balanceOf(address(this))) /
                _totalSupply;
        if (extraAmount0 > 0) {
            TransferHelper.safeTransfer(
                address(token0),
                msg.sender,
                extraAmount0
            );
        }
        uint256 extraAmount1 =
            uint256(burnAmount).mul(token1.balanceOf(address(this))) /
                _totalSupply;
        if (extraAmount1 > 0) {
            TransferHelper.safeTransfer(
                address(token1),
                msg.sender,
                extraAmount1
            );
        }

        amount0 = amount0.add(extraAmount0);
        amount1 = amount1.add(extraAmount1);

        emit Burned(msg.sender, burnAmount, amount0, amount1);
    }

    function rebalance(
        int24 newLowerTick,
        int24 newUpperTick,
        uint160 swapThresholdPrice,
        uint256 swapAmountBPS,
        uint256 feeAmount,
        address paymentToken
    ) external gelatofy(gelato, feeAmount, paymentToken) {
        _adjustCurrentPool(
            newLowerTick,
            newUpperTick,
            swapThresholdPrice,
            swapAmountBPS,
            feeAmount,
            paymentToken
        );

        emit ParamsAdjusted(newLowerTick, newUpperTick);
        lastRebalanceTimestamp = block.timestamp;
    }

    function updateMetaParams(
        uint256 _supplyCap,
        uint256 _heartbeat,
        int24 _minTickDeviation,
        int24 _maxTickDeviation,
        uint32 _observationSeconds,
        uint160 _maxSlippagePercentage
    ) external onlyAdmin {
        supplyCap = _supplyCap;
        heartbeat = _heartbeat;
        maxTickDeviation = _maxTickDeviation;
        minTickDeviation = _minTickDeviation;
        observationSeconds = _observationSeconds;
        maxSlippagePercentage = _maxSlippagePercentage;
        emit MetaParamsAdjusted(
            _supplyCap,
            _heartbeat,
            _minTickDeviation,
            _maxTickDeviation,
            _observationSeconds,
            _maxSlippagePercentage
        );
    }

    function _adjustCurrentPool(
        int24 newLowerTick,
        int24 newUpperTick,
        uint160 swapThresholdPrice,
        uint256 swapAmountBPS,
        uint256 feeAmount,
        address paymentToken
    ) private {
        _checkSlippage(swapThresholdPrice);

        uint256 reinvest0;
        uint256 reinvest1;
        {
            (uint128 _liquidity, , , , ) = pool.positions(_getPositionID());
            _withdraw(currentLowerTick, currentUpperTick, _liquidity);
            uint256 balance0 = token0.balanceOf(address(this));
            uint256 balance1 = token1.balanceOf(address(this));
            reinvest0 = paymentToken == address(token0)
                ? balance0.sub(feeAmount)
                : balance0;
            reinvest1 = paymentToken == address(token1)
                ? balance1.sub(feeAmount)
                : balance1;
        }

        (, int24 _midTick, , , , , ) = pool.slot0();
        if (block.timestamp < lastRebalanceTimestamp.add(heartbeat)) {
            require(
                _midTick > currentUpperTick || _midTick < currentLowerTick,
                "cannot rebalance until heartbeat (price still in range)"
            );
        }
        require(
            _midTick - minTickDeviation >= newLowerTick &&
                newLowerTick >= _midTick - maxTickDeviation,
            "lowerTick out of range"
        );
        require(
            _midTick + maxTickDeviation >= newUpperTick &&
                newUpperTick >= _midTick + minTickDeviation,
            "upperTick out of range"
        );

        // If ticks were adjusted
        if (
            currentLowerTick != newLowerTick || currentUpperTick != newUpperTick
        ) {
            (currentLowerTick, currentUpperTick) = (newLowerTick, newUpperTick);
        }

        _deposit(
            newLowerTick,
            newUpperTick,
            reinvest0,
            reinvest1,
            swapThresholdPrice,
            swapAmountBPS
        );
    }

    function _deposit(
        int24 lowerTick,
        int24 upperTick,
        uint256 amount0,
        uint256 amount1,
        uint160 swapThresholdPrice,
        uint256 swapAmountBPS
    ) private {
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();

        // First, deposit as much as we can
        uint128 baseLiquidity =
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(lowerTick),
                TickMath.getSqrtRatioAtTick(upperTick),
                amount0,
                amount1
            );
        (uint256 amountDeposited0, uint256 amountDeposited1) =
            pool.mint(
                address(this),
                lowerTick,
                upperTick,
                baseLiquidity,
                abi.encode(address(this))
            );

        amount0 -= amountDeposited0;
        amount1 -= amountDeposited1;

        // We need to swap the leftover so were balanced, then deposit it
        if (amount0 > 0 || amount1 > 0) {
            bool zeroForOne = amount0 > amount1;
            int256 swapAmount =
                int256(
                    (zeroForOne ? amount0 : amount1).mul(swapAmountBPS) / 10000
                );
            (amount0, amount1) = _swapAndDeposit(
                lowerTick,
                upperTick,
                amount0,
                amount1,
                swapAmount,
                swapThresholdPrice,
                zeroForOne
            );
        }
    }

    function _swapAndDeposit(
        int24 lowerTick,
        int24 upperTick,
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
                abi.encode(address(this))
            );

        finalAmount0 = uint256(int256(amount0) - amount0Delta);
        finalAmount1 = uint256(int256(amount1) - amount1Delta);

        // Add liquidity a second time
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        uint128 swapLiquidity =
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(lowerTick),
                TickMath.getSqrtRatioAtTick(upperTick),
                finalAmount0,
                finalAmount1
            );

        pool.mint(
            address(this),
            lowerTick,
            upperTick,
            swapLiquidity,
            abi.encode(address(this))
        );
    }

    function _checkSlippage(uint160 swapThresholdPrice) private view {
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = observationSeconds;
        secondsAgo[1] = 0;
        (int56[] memory tickCumulatives, ) = pool.observe(secondsAgo);
        require(tickCumulatives.length == 2, "unexpected length of tick array");
        int24 avgTick =
            int24(
                (tickCumulatives[1] - tickCumulatives[0]) / observationSeconds
            );
        uint160 avgSqrtRatioX96 = TickMath.getSqrtRatioAtTick(avgTick);
        uint160 maxSlippage = (avgSqrtRatioX96 * maxSlippagePercentage) / 100;
        require(
            avgSqrtRatioX96 + maxSlippage >= swapThresholdPrice &&
                avgSqrtRatioX96 - maxSlippage <= swapThresholdPrice,
            "slippage price is out of acceptable price range"
        );
    }

    function _withdraw(
        int24 lowerTick,
        int24 upperTick,
        uint128 liquidity
    ) private {
        pool.burn(lowerTick, upperTick, liquidity);
        pool.collect(
            address(this),
            lowerTick,
            upperTick,
            type(uint128).max,
            type(uint128).max
        );
    }

    // HELPERS

    function getLiquidityForAmounts(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0,
        uint256 amount1
    ) external pure returns (uint128 liquidity) {
        return
            LiquidityAmounts.getLiquidityForAmounts(
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
        return
            LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                sqrtRatioAX96,
                sqrtRatioBX96,
                liquidity
            );
    }

    function getPositionID() external view returns (bytes32 positionID) {
        return _getPositionID();
    }

    function _getPositionID() private view returns (bytes32 positionID) {
        return
            keccak256(
                abi.encodePacked(
                    address(this),
                    currentLowerTick,
                    currentUpperTick
                )
            );
    }

    // CALLBACKS
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external override {
        require(msg.sender == address(pool));

        address sender = abi.decode(data, (address));

        if (sender == address(this)) {
            if (amount0Owed > 0) {
                TransferHelper.safeTransfer(
                    address(token0),
                    msg.sender,
                    amount0Owed
                );
            }
            if (amount1Owed > 0) {
                TransferHelper.safeTransfer(
                    address(token1),
                    msg.sender,
                    amount1Owed
                );
            }
        } else {
            if (amount0Owed > 0) {
                TransferHelper.safeTransferFrom(
                    address(token0),
                    sender,
                    msg.sender,
                    amount0Owed
                );
            }
            if (amount1Owed > 0) {
                TransferHelper.safeTransferFrom(
                    address(token1),
                    sender,
                    msg.sender,
                    amount1Owed
                );
            }
        }
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata /*data*/
    ) external override {
        require(msg.sender == address(pool));

        if (amount0Delta > 0) {
            TransferHelper.safeTransfer(
                address(token0),
                msg.sender,
                uint256(amount0Delta)
            );
        } else if (amount1Delta > 0) {
            TransferHelper.safeTransfer(
                address(token1),
                msg.sender,
                uint256(amount1Delta)
            );
        }
    }
}
