// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {
    ERC20,
    ERC20Permit
} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

/// @dev DO NOT ADD STATE VARIABLES - APPEND THEM TO GelatoUniV3PoolStorage
/// @dev DO NOT ADD BASE CONTRACTS WITH STATE VARS - APPEND THEM TO GelatoUniV3PoolStorage
abstract contract GUni is ERC20Permit {
    string private constant _NAME = "Gelato Uniswap V3 INST/ETH LP 1";
    string private constant _SYMBOL = "G-UNI";
    uint8 private constant _DECIMALS = 18;

    constructor() ERC20("", "") ERC20Permit(_NAME) {} // solhint-disable-line no-empty-blocks

    function name() public view override returns (string memory) {
        this; // silence compiler pure warning
        return _NAME;
    }

    function symbol() public view override returns (string memory) {
        this; // silence compiler pure warning
        return _SYMBOL;
    }

    function decimals() public view override returns (uint8) {
        this; // silence compiler pure warning
        return _DECIMALS;
    }
}
