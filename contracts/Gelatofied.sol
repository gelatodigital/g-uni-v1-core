// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.3;

import {TransferHelper} from "./libraries/TransferHelper.sol";

abstract contract Gelatofied {
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    modifier gelatofy(
        address _gelato,
        uint256 _amount,
        address _paymentToken
    ) {
        require(msg.sender == _gelato, "Gelatofied: Only gelato");
        _;
        if (_paymentToken == ETH) {
            TransferHelper.safeTransferETH(_gelato, _amount);
        } else {
            TransferHelper.safeTransfer(_paymentToken, _gelato, _amount);
        }
    }
}
