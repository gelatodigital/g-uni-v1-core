//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IGUniFactory} from "./interfaces/IGUniFactory.sol";
import {IGUniPoolStorage} from "./interfaces/IGUniPoolStorage.sol";
import {GUniFactoryStorage} from "./abstract/GUniFactoryStorage.sol";
import {GUniEIP173Proxy} from "./vendor/proxy/GUniEIP173Proxy.sol";
import {IEIP173Proxy} from "./interfaces/IEIP173Proxy.sol";
import {
    IERC20Metadata
} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract GUniFactory is GUniFactoryStorage, IGUniFactory {
    bytes32 public constant PROXY_BYTECODE_HASH =
        keccak256(type(GUniEIP173Proxy).creationCode);

    constructor(address _factory) GUniFactoryStorage(_factory) {} // solhint-disable-line no-empty-blocks, max-line-length

    function getPoolAddress(
        address manager,
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address) {
        (address token0, address token1) = getTokenOrder(tokenA, tokenB);
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                address(this),
                                keccak256(
                                    abi.encodePacked(
                                        manager,
                                        token0,
                                        token1,
                                        fee
                                    )
                                ),
                                PROXY_BYTECODE_HASH
                            )
                        )
                    )
                )
            );
    }

    // solhint-disable-next-line function-max-lines
    function createPool(
        address tokenA,
        address tokenB,
        uint24 uniFee,
        uint16 managerFee,
        int24 lowerTick,
        int24 upperTick
    ) external override returns (address pool) {
        (address token0, address token1) = getTokenOrder(tokenA, tokenB);

        _constructorParams = ConstructorParams({
            owner: address(this),
            implementation: poolImplementation
        });

        pool = address(
            new GUniEIP173Proxy{
                salt: keccak256(
                    abi.encodePacked(msg.sender, token0, token1, uniFee)
                )
            }()
        );

        string memory symbol0 = "?";
        string memory symbol1 = "?";
        try IERC20Metadata(token0).symbol() returns (string memory sym0) {
            symbol0 = sym0;
        } catch {} // solhint-disable-line no-empty-blocks
        try IERC20Metadata(token1).symbol() returns (string memory sym1) {
            symbol1 = sym1;
        } catch {} // solhint-disable-line no-empty-blocks

        string memory name =
            _append(
                "Gelato Uniswap V3 ",
                symbol0,
                "/",
                symbol1,
                " LP 0x",
                _getAddressFingerprint(msg.sender)
            );

        address uniPool =
            IUniswapV3Factory(factory).getPool(token0, token1, uniFee);

        IGUniPoolStorage(pool).initialize(
            name,
            "G-UNI",
            uniPool,
            managerFee,
            lowerTick,
            upperTick,
            msg.sender
        );

        delete _constructorParams;
        isPoolCreator[msg.sender] = true;
        emit PoolCreated(uniPool, msg.sender, pool);
    }

    function upgradeImplementations(address[] memory pools)
        external
        onlyManager
    {
        for (uint256 i = 0; i < pools.length; i++) {
            IEIP173Proxy(pools[i]).upgradeTo(poolImplementation);
        }
    }

    function upgradeImplmentationsAndCall(
        address[] memory pools,
        bytes calldata data
    ) external onlyManager {
        for (uint256 i = 0; i < pools.length; i++) {
            IEIP173Proxy(pools[i]).upgradeToAndCall(poolImplementation, data);
        }
    }

    function getTokenOrder(address tokenA, address tokenB)
        public
        pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, "GUniFactory.createPool: same token");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(
            token0 != address(0),
            "GUniFactory.createPool: not address zero"
        );
    }

    function _getAddressFingerprint(address addr)
        internal
        pure
        returns (string memory)
    {
        bytes32 value = bytes32(uint256(uint160(addr)));
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(6);
        for (uint256 i = 0; i < 3; i++) {
            str[i * 2] = alphabet[uint256(uint8(value[i + 12] >> 4))];
            str[1 + i * 2] = alphabet[uint256(uint8(value[i + 12] & 0x0f))];
        }
        return string(str);
    }

    function _append(
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e,
        string memory f
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d, e, f));
    }
}
