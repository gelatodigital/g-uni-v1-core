// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import "../abstract/GUNIV3.sol";

contract MockERC20 is GUNIV3 {
    constructor() {
        _mint(msg.sender, 100000e18);
    }
}
