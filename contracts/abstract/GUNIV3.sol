// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.7.0;

import {
    ERC20,
    ERC20Permit
} from "@openzeppelin/contracts/drafts/ERC20Permit.sol";

/// @dev DO NOT ADD STATE VARIABLES - APPEND THEM TO GelatoUniV3PoolStorage
/// @dev DO NOT ADD BASE CONTRACTS WITH STATE VARS - APPEND THEM TO GelatoUniV3PoolStorage
abstract contract GUNIV3 is ERC20Permit {
    string private constant _NAME = "Gelato Uniswap V3 WETH/DAI LP";
    string private constant _SYMBOL = "G-UNI";

    constructor() ERC20("", "") ERC20Permit(_NAME) {} // solhint-disable-line no-empty-blocks

    function name() public view override returns (string memory) {
        this; // silence compiler pure warning
        return _NAME;
    }

    function symbol() public view override returns (string memory) {
        this; // silence compiler pure warning
        return _SYMBOL;
    }
}
