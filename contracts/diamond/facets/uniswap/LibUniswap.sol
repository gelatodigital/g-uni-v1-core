// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

library LibUniswap {
    struct UniswapStorage {
        address pool;
        address token0;
        address token1;
    }

    bytes32 private constant _UNISWAP_STORAGE =
        keccak256("uniswap.storage.location");

    function setPool(address _pool) internal {
        LibUniswap.uniswapStorage().pool = _pool;
    }

    function setToken0(address _token0) internal {
        LibUniswap.uniswapStorage().token0 = _token0;
    }

    function setToken1(address _token0) internal {
        LibUniswap.uniswapStorage().token1 = _token1;
    }

    function getPool() internal view returns (address) {
        return uniswapStorage().pool;
    }

    function getToken0() internal view returns (address) {
        return uniswapStorage().token0;
    }

    function getToken1() internal view returns (address) {
        return uniswapStorage().token1;
    }

    function uniswapStorage()
        internal
        pure
        returns (UniswapStorage storage ads)
    {
        bytes32 position = _UNISWAP_STORAGE;
        assembly {
            ads.slot := position
        }
    }
}
