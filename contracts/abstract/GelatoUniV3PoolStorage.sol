// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.4;

import {GUNIV3} from "./GUNIV3.sol";
import {Gelatofied} from "./Gelatofied.sol";
import {OwnableUninitialized} from "./OwnableUninitialized.sol";
import {
    Initializable
} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {
    IERC20Minimal
} from "@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @dev Single Global upgradeable state var storage base: APPEND ONLY
// solhint-disable-next-line max-states-count
abstract contract GelatoUniV3PoolStorage is
    GUNIV3,
    Gelatofied,
    OwnableUninitialized,
    Initializable,
    ReentrancyGuard
{
    address public immutable deployer;

    IUniswapV3Pool public immutable pool;
    IERC20Minimal public immutable token0;
    IERC20Minimal public immutable token1;

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

    // APPPEND ADDITIONAL STATE VARS BELOW:

    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX

    constructor(IUniswapV3Pool _pool, address _gelato) Gelatofied(_gelato) {
        deployer = msg.sender;

        pool = _pool;
        token0 = IERC20Minimal(_pool.token0());
        token1 = IERC20Minimal(_pool.token1());
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
