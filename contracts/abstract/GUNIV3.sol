// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {ERC20Permit} from "./ERC20Permit.sol";

/// @dev DO NOT ADD STATE VARIABLES - APPEND THEM TO GelatoUniV3PoolStorage
/// @dev DO NOT ADD BASE CONTRACTS WITH STATE VARS - APPEND THEM TO GelatoUniV3PoolStorage
abstract contract GUNIV3 is ERC20Permit {
    // solhint-disable-next-line no-empty-blocks
    constructor() ERC20Permit("Gelato Uniswap V3 WETH/DAI LP") {}
}
