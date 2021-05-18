//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../ERC20MintBurnPermit.sol";

contract MockERC20 is ERC20MintBurnPermit {
    constructor() {
        _mint(msg.sender, 100000e18);
    }
}
