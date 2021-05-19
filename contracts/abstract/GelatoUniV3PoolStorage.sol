// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import {GUNIV3} from "./GUNIV3.sol";
import {Gelatofied} from "./Gelatofied.sol";
import {OwnableUninitialized} from "./OwnableUninitialized.sol";
import {UniswapV3Helpers} from "./UniswapV3Helpers.sol";
import {
    Initializable
} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @dev Single Global upgradeable state var storage base: APPEND ONLY
/// @dev Add all inherited contracts with state vars here: APPEND ONLY
// solhint-disable-next-line max-states-count
abstract contract GelatoUniV3PoolStorage is
    GUNIV3, /* // XXXX DONT MODIFY ORDERING XXXX*/
    Gelatofied,
    OwnableUninitialized,
    Initializable,
    ReentrancyGuard,
    UniswapV3Helpers
    // APPEND ADDITIONAL BASE WITH STATE VARS HERE
    // XXXX DONT MODIFY ORDERING XXXX
{
    address public immutable deployer;

    IUniswapV3Pool public immutable pool;
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX
    uint256 internal _supplyCap;
    uint256 internal _heartbeat;
    int24 internal _minTickDeviation;
    int24 internal _maxTickDeviation;
    uint32 internal _observationSeconds;
    uint160 internal _maxSlippagePercentage;

    int24 internal _currentLowerTick;
    int24 internal _currentUpperTick;
    uint256 internal _lastRebalanceTimestamp;
    uint256 internal _lastMintOrBurnTimestamp;

    // APPPEND ADDITIONAL STATE VARS BELOW:

    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX

    event MetaParamsAdjusted(
        uint256 supplyCap,
        uint256 heartbeat,
        int24 minTickDeviation,
        int24 maxTickDeviation,
        uint32 observationSeconds,
        uint160 maxSlippagePercentage
    );

    constructor(IUniswapV3Pool _pool, address payable _gelato)
        Gelatofied(_gelato)
    {
        deployer = msg.sender;

        pool = _pool;
        token0 = IERC20(_pool.token0());
        token1 = IERC20(_pool.token1());
    }

    function initialize(
        uint256 __supplyCap,
        int24 _lowerTick,
        int24 _upperTick,
        address _owner_
    ) external initializer {
        require(
            msg.sender == deployer,
            "GelatoUniV3PoolStorage.initialize: only deployer"
        );
        _supplyCap = __supplyCap;
        _heartbeat = 1 days; // default: one day
        _minTickDeviation = 120; // default: ~1% price difference up and down
        _maxTickDeviation = 7000; // default: ~100% price difference up and down
        _observationSeconds = 5 minutes; // default: last five minutes;
        _maxSlippagePercentage = 5; //default: 5% slippage

        _currentLowerTick = _lowerTick;
        _currentUpperTick = _upperTick;

        _owner = _owner_;
    }

    function updateMetaParams(
        uint256 __supplyCap,
        uint256 __heartbeat,
        int24 __minTickDeviation,
        int24 __maxTickDeviation,
        uint32 __observationSeconds,
        uint160 __maxSlippagePercentage
    ) external onlyOwner {
        _supplyCap = __supplyCap;
        _heartbeat = __heartbeat;
        _minTickDeviation = __minTickDeviation;
        _maxTickDeviation = __maxTickDeviation;
        _observationSeconds = __observationSeconds;
        _maxSlippagePercentage = __maxSlippagePercentage;
        emit MetaParamsAdjusted(
            __supplyCap,
            __heartbeat,
            __minTickDeviation,
            __maxTickDeviation,
            __observationSeconds,
            __maxSlippagePercentage
        );
    }

    function supplyCap() external view returns (uint256) {
        return _supplyCap;
    }

    function heartbeat() external view returns (uint256) {
        return _heartbeat;
    }

    function minTickDeviation() external view returns (int24) {
        return _minTickDeviation;
    }

    function maxTickDeviation() external view returns (int24) {
        return _maxTickDeviation;
    }

    function observationSeconds() external view returns (uint32) {
        return _observationSeconds;
    }

    function maxSlippagePercentage() external view returns (uint160) {
        return _maxSlippagePercentage;
    }

    function currentLowerTick() external view returns (int24) {
        return _currentLowerTick;
    }

    function currentUpperTick() external view returns (int24) {
        return _currentUpperTick;
    }

    function lastRebalanceTimestamp() external view returns (uint256) {
        return _lastRebalanceTimestamp;
    }

    function lastMintOrBurnTimestamp() external view returns (uint256) {
        return _lastMintOrBurnTimestamp;
    }

    function getPositionID() external view returns (bytes32 positionID) {
        return _getPositionID();
    }

    function _getPositionID() internal view returns (bytes32 positionID) {
        return
            keccak256(
                abi.encodePacked(
                    address(this),
                    _currentLowerTick,
                    _currentUpperTick
                )
            );
    }
}
