// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import {LibUniswap} from "./LibUniswap.sol";
import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract UniswapFacet {

    using LibUniswap for address;
    using SafeERC20 for IERC20;
    
    // Only called once by the factoy, thus we dont need initializable, might still want to add it though
    function initialize(
        address _pool,
        address _token0,
        address _token1
    ) external onlyOwner {
        LibUniswap.setPool(_pool);
        LibUniswap.setToken0(_token0);
        LibUniswap.setToken1(_token1);
    }
    
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata /*_data*/
    ) external override {
        require(msg.sender == LibUniswap.getPool());

        if (amount0Owed > 0) IERC20(LibUniswap.getToken0()).safeTransfer(msg.sender, amount0Owed);
        if (amount1Owed > 0) IERC20(LibUniswap.getToken1()).safeTransfer(msg.sender, amount1Owed);
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata /*data*/
    ) external override {
        require(msg.sender == LibUniswap.getPool());

        if (amount0Delta > 0)
            IERC20(LibUniswap.getToken0()).safeTransfer(msg.sender, uint256(amount0Delta));
        else if (amount1Delta > 0)
            IERC20(LibUniswap.getToken1()).safeTransfer(msg.sender, uint256(amount1Delta));
    }

}