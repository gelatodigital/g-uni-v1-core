//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface IMetaPoolFactory {
    event PoolCreated(
        address indexed token0,
        address indexed token1,
        address pool
    );

    function createPool(
        string calldata name,
        address tokenA,
        address tokenB,
        int24 initialLowerTick,
        int24 initialUpperTick
    ) external returns (address pool);

    function getDeployProps()
        external
        view
        returns (
            address,
            address,
            address,
            int24,
            int24,
            address,
            address,
            string memory
        );
}
