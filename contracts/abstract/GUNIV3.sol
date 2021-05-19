// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {
    ERC20,
    ERC20Permit
} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

/// @dev DO NOT ADD STATE VARIABLES - APPEND THEM TO GelatoUniV3PoolStorage
/// @dev DO NOT ADD BASE CONTRACTS WITH STATE VARS - APPEND THEM TO GelatoUniV3PoolStorage
abstract contract GUNIV3 is ERC20Permit {
    constructor()
        ERC20("Gelato Uniswap V3 WETH/DAI LP", "gUNIV3")
        ERC20Permit("Gelato Uniswap V3 WETH/DAI LP")
    {} // solhint-disable-line no-empty-blocks
}
