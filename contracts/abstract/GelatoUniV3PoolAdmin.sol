// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.4;

import {GelatoUniV3PoolStorage} from "./GelatoUniV3PoolStorage.sol";

/// @dev DO NOT ADD STATE VARIABLES - APPEND THEM TO GelatoUniV3PoolStorage
abstract contract GelatoUniV3PoolAdmin is GelatoUniV3PoolStorage {
    event MetaParamsAdjusted(
        uint256 supplyCap,
        uint256 heartbeat,
        int24 minTickDeviation,
        int24 maxTickDeviation,
        uint32 observationSeconds,
        uint160 maxSlippagePercentage
    );

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
}
