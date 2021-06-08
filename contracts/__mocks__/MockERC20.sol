// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import "../abstract/GUni.sol";

contract MockERC20 is GUni {
    constructor() {
        _mint(msg.sender, 100000e18);
    }
}
