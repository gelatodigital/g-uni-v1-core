//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

// import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
// import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IMetaPoolFactory} from "./interfaces/IMetaPoolFactory.sol";
import {MetaPool} from "./MetaPool.sol";

contract MetaPoolFactory is IMetaPoolFactory {
    address private _token0;
    address private _token1;

    int24 private _initialLowerTick;
    int24 private _initialUpperTick;

    string private _name;

    address public immutable uniswapFactory;
    address public immutable gelato;
    address public immutable owner;

    bytes32 public constant POOL_BYTECODE_HASH =
        keccak256(type(MetaPool).creationCode);

    constructor(
        address _uniswapFactory,
        address _gelato,
        address _owner
    ) {
        uniswapFactory = _uniswapFactory;
        gelato = _gelato;
        owner = _owner;
    }

    function calculatePoolAddress(address tokenA, address tokenB)
        external
        view
        returns (address)
    {
        (address token0, address token1) =
            tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return
            address(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            byte(0xff),
                            address(this),
                            keccak256(abi.encodePacked(token0, token1)),
                            POOL_BYTECODE_HASH
                        )
                    )
                )
            );
    }

    function createPool(
        string calldata name,
        address tokenA,
        address tokenB,
        int24 initialLowerTick,
        int24 initialUpperTick
    ) external override returns (address pool) {
        require(tokenA != tokenB);
        (address token0, address token1) =
            tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0));

        _token0 = token0;
        _token1 = token1;
        _initialLowerTick = initialLowerTick;
        _initialUpperTick = initialUpperTick;
        _name = name;

        pool = address(
            new MetaPool{salt: keccak256(abi.encodePacked(token0, token1))}()
        );

        _token0 = address(0);
        _token1 = address(0);
        _initialLowerTick = 0;
        _initialUpperTick = 0;
        _name = "";

        emit PoolCreated(token0, token1, pool);
    }

    function getDeployProps()
        external
        view
        override
        returns (
            address,
            address,
            address,
            int24,
            int24,
            address,
            address,
            string memory
        )
    {
        return (
            _token0,
            _token1,
            uniswapFactory,
            _initialLowerTick,
            _initialUpperTick,
            gelato,
            owner,
            _name
        );
    }
}
