// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.4;

import {TransferHelper} from "../libraries/TransferHelper.sol";

abstract contract Gelatofied {
    using TransferHelper for address;

    // solhint-disable-next-line var-name-mixedcase
    address public immutable GELATO;

    address private constant _ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    constructor(address _gelato) {
        GELATO = _gelato;
    }

    modifier gelatofy(uint256 _amount, address _paymentToken) {
        require(msg.sender == GELATO, "Gelatofied: Only gelato");
        _;
        if (_paymentToken == _ETH) GELATO.safeTransferETH(_amount);
        else _paymentToken.safeTransfer(GELATO, _amount);
    }
}
