// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract MockERC20 is ERC20Upgradeable {
    constructor() {
        __ERC20_init("Gelato Uniswap V3 INST/ETH LP", "G-UNI");
        _mint(msg.sender, 100000e18);
    }
}
