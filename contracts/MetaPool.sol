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
    LowGasSafeMath
} from "@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol";
import {
    IUniswapV3SwapCallback
} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import {IMetaPoolFactory} from "./interfaces/IMetaPoolFactory.sol";
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

    IMetaPoolFactory public immutable factory;
    address public immutable token0;
    address public immutable token1;

    int24 public currentLowerTick;
    int24 public currentUpperTick;
    uint24 public currentUniswapFee;

    IUniswapV3Pool public currentPool;
    IUniswapV3Factory public immutable uniswapFactory;

    address public immutable gelato;

    uint24 private constant DEFAULT_UNISWAP_FEE = 3000;
    int24 private constant MIN_TICK = -887220;
    int24 private constant MAX_TICK = 887220;

    uint256 public lastRebalanceTimestamp;

    uint256 public supplyCap = 15000 * 10**18; // default: 15,000 gUNIV3
    uint256 public heartbeat = 86400; // default: one day
    int24 public minTickDeviation = 120; // default: ~1% price difference up and down
    int24 public maxTickDeviation = 7000; // default: ~100% price difference up and down
    bool public disablePoolSwitch; // default: false (can switch pools)
    uint32 public observationSeconds = 300; // default: last five minutes;
    uint160 public maxSlippagePercentage = 5; //default: 5% slippage

    event ParamsAdjusted(
        int24 newLowerTick,
        int24 newUpperTick,
        uint24 newUniswapFee
    );

    event MetaParamsAdjusted(
        uint256 supplyCap,
        uint256 heartbeat,
        int24 minTickDeviation,
        int24 maxTickDeviation,
        bool disablePoolSwitch,
        uint32 observationSeconds,
        uint160 maxSlippagePercentage
    );

    constructor() {
        IMetaPoolFactory _factory = IMetaPoolFactory(msg.sender);
        factory = _factory;

        (
            address _token0,
            address _token1,
            address _uniswapFactory,
            int24 _initialLowerTick,
            int24 _initialUpperTick,
            address _gelato,
            address _owner,
            string memory _name
        ) = _factory.getDeployProps();
        token0 = _token0;
        token1 = _token1;
        uniswapFactory = IUniswapV3Factory(_uniswapFactory);
        gelato = _gelato;
        transferOwnership(_owner);
        _setName(_name);

        // All metapools start with 0.30% fees & liquidity spread across the entire curve
        currentLowerTick = _initialLowerTick;
        currentUpperTick = _initialUpperTick;
        currentUniswapFee = DEFAULT_UNISWAP_FEE;

        address uniswapPool =
            IUniswapV3Factory(_uniswapFactory).getPool(
                _token0,
                _token1,
                DEFAULT_UNISWAP_FEE
            );
        require(uniswapPool != address(0));
        currentPool = IUniswapV3Pool(uniswapPool);
    }

    function mint(uint128 newLiquidity) external returns (uint256 mintAmount) {
        require(newLiquidity > 0);
        (int24 _currentLowerTick, int24 _currentUpperTick) =
            (currentLowerTick, currentUpperTick);
        IUniswapV3Pool _currentPool = currentPool;

        (uint128 _liquidity, , , , ) = _currentPool.positions(_getPositionID());

        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            mintAmount = newLiquidity;
        } else {
            mintAmount = uint256(newLiquidity).mul(_totalSupply) / _liquidity;
        }
        require(
            supplyCap >= _totalSupply.add(mintAmount),
            "cannot mint more than supplyCap"
        );

        _currentPool.mint(
            address(this),
            _currentLowerTick,
            _currentUpperTick,
            newLiquidity,
            abi.encode(msg.sender)
        );

        _mint(msg.sender, mintAmount);
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
        (int24 _currentLowerTick, int24 _currentUpperTick) =
            (currentLowerTick, currentUpperTick);
        IUniswapV3Pool _currentPool = currentPool;
        uint256 _totalSupply = totalSupply;

        (uint128 _liquidity, , , , ) = _currentPool.positions(_getPositionID());

        _burn(msg.sender, burnAmount);

        uint256 _liquidityBurned = burnAmount.mul(_liquidity) / _totalSupply;
        require(_liquidityBurned < type(uint128).max);
        liquidityBurned = uint128(_liquidityBurned);

        (amount0, amount1) = currentPool.burn(
            _currentLowerTick,
            _currentUpperTick,
            liquidityBurned
        );

        // Withdraw tokens to user
        _currentPool.collect(
            msg.sender,
            _currentLowerTick,
            _currentUpperTick,
            uint128(amount0), // cast can't overflow
            uint128(amount1) // cast can't overflow
        );
    }

    function rebalance(
        int24 newLowerTick,
        int24 newUpperTick,
        uint24 newUniswapFee,
        uint160 swapThresholdPrice,
        uint256 feeAmount,
        address paymentToken
    ) external gelatofy(gelato, feeAmount, paymentToken) {
        // If we're swapping pools
        if (currentUniswapFee != newUniswapFee) {
            require(!disablePoolSwitch, "switchPools disabled");
            _switchPools(
                newLowerTick,
                newUpperTick,
                newUniswapFee,
                swapThresholdPrice,
                feeAmount,
                paymentToken
            );
        } else {
            // Else we're just adjusting ticks or reinvesting fees
            _adjustCurrentPool(
                newLowerTick,
                newUpperTick,
                swapThresholdPrice,
                feeAmount,
                paymentToken
            );
        }

        emit ParamsAdjusted(newLowerTick, newUpperTick, newUniswapFee);
        lastRebalanceTimestamp = block.timestamp;
    }

    function updateMetaParams(
        uint256 _supplyCap,
        uint256 _heartbeat,
        int24 _minTickDeviation,
        int24 _maxTickDeviation,
        bool _disablePoolSwitch,
        uint32 _observationSeconds,
        uint160 _maxSlippagePercentage
    ) external onlyOwner {
        supplyCap = _supplyCap;
        heartbeat = _heartbeat;
        maxTickDeviation = _maxTickDeviation;
        minTickDeviation = _minTickDeviation;
        disablePoolSwitch = _disablePoolSwitch;
        observationSeconds = _observationSeconds;
        maxSlippagePercentage = _maxSlippagePercentage;
        emit MetaParamsAdjusted(
            _supplyCap,
            _heartbeat,
            _minTickDeviation,
            _maxTickDeviation,
            _disablePoolSwitch,
            _observationSeconds,
            _maxSlippagePercentage
        );
    }

    function _switchPools(
        int24 newLowerTick,
        int24 newUpperTick,
        uint24 newUniswapFee,
        uint160 swapThresholdPrice,
        uint256 feeAmount,
        address paymentToken
    ) private {
        (
            IUniswapV3Pool _currentPool,
            int24 _currentLowerTick,
            int24 _currentUpperTick
        ) = (currentPool, currentLowerTick, currentUpperTick);
        uint256 reinvest0;
        uint256 reinvest1;
        {
            (uint128 _liquidity, , , , ) =
                _currentPool.positions(_getPositionID());
            (uint256 collected0, uint256 collected1) =
                _withdraw(
                    _currentPool,
                    _currentLowerTick,
                    _currentUpperTick,
                    _liquidity
                );
            reinvest0 = paymentToken == token0
                ? collected0.sub(feeAmount)
                : collected0;
            reinvest1 = paymentToken == token1
                ? collected1.sub(feeAmount)
                : collected1;
        }

        IUniswapV3Pool newPool =
            IUniswapV3Pool(
                uniswapFactory.getPool(token0, token1, newUniswapFee)
            );

        (, int24 _midTick, , , , , ) = newPool.slot0();
        if (block.timestamp < lastRebalanceTimestamp.add(heartbeat)) {
            require(
                _midTick > _currentUpperTick || _midTick < _currentLowerTick,
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

        // Store new paramaters as "current"
        (currentLowerTick, currentUpperTick, currentUniswapFee, currentPool) = (
            newLowerTick,
            newUpperTick,
            newUniswapFee,
            newPool
        );

        _checkSlippage(newPool, swapThresholdPrice);

        _deposit(
            newPool,
            newLowerTick,
            newUpperTick,
            reinvest0,
            reinvest1,
            swapThresholdPrice
        );
    }

    function _adjustCurrentPool(
        int24 newLowerTick,
        int24 newUpperTick,
        uint160 swapThresholdPrice,
        uint256 feeAmount,
        address paymentToken
    ) private {
        (
            IUniswapV3Pool _currentPool,
            int24 _currentLowerTick,
            int24 _currentUpperTick
        ) = (currentPool, currentLowerTick, currentUpperTick);
        _checkSlippage(_currentPool, swapThresholdPrice);

        uint256 reinvest0;
        uint256 reinvest1;
        {
            (uint128 _liquidity, , , , ) =
                _currentPool.positions(_getPositionID());
            (uint256 collected0, uint256 collected1) =
                _withdraw(
                    _currentPool,
                    _currentLowerTick,
                    _currentUpperTick,
                    _liquidity
                );
            reinvest0 = paymentToken == token0
                ? collected0.sub(feeAmount)
                : collected0;
            reinvest1 = paymentToken == token1
                ? collected1.sub(feeAmount)
                : collected1;
        }

        (, int24 _midTick, , , , , ) = _currentPool.slot0();
        if (block.timestamp < lastRebalanceTimestamp.add(heartbeat)) {
            require(
                _midTick > _currentUpperTick || _midTick < _currentLowerTick,
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
            _currentLowerTick != newLowerTick ||
            _currentUpperTick != newUpperTick
        ) {
            (currentLowerTick, currentUpperTick) = (newLowerTick, newUpperTick);
        }

        _deposit(
            _currentPool,
            newLowerTick,
            newUpperTick,
            reinvest0,
            reinvest1,
            swapThresholdPrice
        );
    }

    function _deposit(
        IUniswapV3Pool _currentPool,
        int24 lowerTick,
        int24 upperTick,
        uint256 amount0,
        uint256 amount1,
        uint160 swapThresholdPrice
    ) private {
        (uint160 sqrtRatioX96, , , , , , ) = _currentPool.slot0();

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
            _currentPool.mint(
                address(this),
                lowerTick,
                upperTick,
                baseLiquidity,
                abi.encode(address(this))
            );

        amount0 -= amountDeposited0;
        amount1 -= amountDeposited1;

        // If we still have some leftover, we need to swap so it's balanced
        if (amount0 > 0 || amount1 > 0) {
            // @dev OG comment: this is a hacky method that only works at somewhat-balanced pools
            bool zeroForOne = amount0 > amount1;
            (int256 amount0Delta, int256 amount1Delta) =
                _currentPool.swap(
                    address(this),
                    zeroForOne,
                    int256(zeroForOne ? amount0 : amount1) / 2,
                    swapThresholdPrice,
                    abi.encode(address(this))
                );

            amount0 = uint256(int256(amount0) - amount0Delta);
            amount1 = uint256(int256(amount1) - amount1Delta);

            // Add liquidity a second time
            (sqrtRatioX96, , , , , , ) = _currentPool.slot0();
            uint128 swapLiquidity =
                LiquidityAmounts.getLiquidityForAmounts(
                    sqrtRatioX96,
                    TickMath.getSqrtRatioAtTick(lowerTick),
                    TickMath.getSqrtRatioAtTick(upperTick),
                    amount0,
                    amount1
                );

            _currentPool.mint(
                address(this),
                lowerTick,
                upperTick,
                swapLiquidity,
                abi.encode(address(this))
            );
        }
    }

    function _checkSlippage(
        IUniswapV3Pool _currentPool,
        uint160 swapThresholdPrice
    ) private view {
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = observationSeconds;
        secondsAgo[1] = 0;
        (int56[] memory tickCumulatives, ) = _currentPool.observe(secondsAgo);
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
        IUniswapV3Pool _currentPool,
        int24 lowerTick,
        int24 upperTick,
        uint128 liquidity
    ) private returns (uint256 collected0, uint256 collected1) {
        _currentPool.burn(lowerTick, upperTick, liquidity);
        (collected0, collected1) = _currentPool.collect(
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
        require(msg.sender == address(currentPool));

        address sender = abi.decode(data, (address));

        if (sender == address(this)) {
            if (amount0Owed > 0) {
                TransferHelper.safeTransfer(token0, msg.sender, amount0Owed);
            }
            if (amount1Owed > 0) {
                TransferHelper.safeTransfer(token1, msg.sender, amount1Owed);
            }
        } else {
            if (amount0Owed > 0) {
                TransferHelper.safeTransferFrom(
                    token0,
                    sender,
                    msg.sender,
                    amount0Owed
                );
            }
            if (amount1Owed > 0) {
                TransferHelper.safeTransferFrom(
                    token1,
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
        require(msg.sender == address(currentPool));

        if (amount0Delta > 0) {
            TransferHelper.safeTransfer(
                token0,
                msg.sender,
                uint256(amount0Delta)
            );
        } else if (amount1Delta > 0) {
            TransferHelper.safeTransfer(
                token1,
                msg.sender,
                uint256(amount1Delta)
            );
        }
    }
}
