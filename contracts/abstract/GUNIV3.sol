// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {
    ERC20,
    ERC20Permit
} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

abstract contract GUNIV3 is ERC20Permit {
    constructor()
        ERC20("Gelato Uniswap V3 WETH/DAI LP", "gUNIV3")
        ERC20Permit("Gelato Uniswap V3 WETH/DAI LP")
    {} // solhint-disable-line no-empty-blocks
}
