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

    /// @notice getPoolAddress gets the deterministic address of any G-UNI token
    /// Functions similarly to UniswapV3Factory's getPool method with the addition of one
    /// important `manager` parameter. This parameter allows for multiple G-UNI token instances
    /// on the same UniswapV3 trading pair given that they were deployed by a different `manager`
    /// @param manager the account who deployed and initially managed the pool
    /// @param tokenA one of the tokens in the uniswap pair
    /// @param tokenB other token in the uniswap pair
    /// @param fee fee tier of the uniswap pair (500, 3000, 10000)
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

    /// @notice createPool creates a new instance of a G-UNI token on a specified
    /// UniswapV3 pool. The msg.sender is the initial manager of the pool and will
    /// forever be associated with the deterministic address of this G-UNI pool.
    /// @param tokenA one of the tokens in the uniswap pair
    /// @param tokenB the other token in the uniswap pair
    /// @param uniFee fee tier of the uniswap pair
    /// @param managerFee proportion of earned fees that go to pool manager in Basis Points
    /// @param lowerTick initial lower bound of the Uniswap V3 position
    /// @param upperTick initial upper bound of the Uniswap V3 position
    /// @return pool the (deterministic) address of the newly created G-UNI pool
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

        require(uniPool != address(0), "uniswap pool does not exist");

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
        poolDeployer[msg.sender] = pool;
        emit PoolCreated(uniPool, msg.sender, pool);
    }

    function upgradePools(address[] memory pools) external onlyManager {
        for (uint256 i = 0; i < pools.length; i++) {
            IEIP173Proxy(pools[i]).upgradeTo(poolImplementation);
        }
    }

    function upgradePoolsAndCall(address[] memory pools, bytes[] calldata datas)
        external
        onlyManager
    {
        require(pools.length == datas.length, "mismatching array length");
        for (uint256 i = 0; i < pools.length; i++) {
            IEIP173Proxy(pools[i]).upgradeToAndCall(
                poolImplementation,
                datas[i]
            );
        }
    }

    function transferPools(address[] memory pools, address newAdmin)
        external
        onlyManager
    {
        for (uint256 i = 0; i < pools.length; i++) {
            IEIP173Proxy(pools[i]).transferProxyAdmin(newAdmin);
        }
    }

    /// @notice poolProxyAdmin gets the current address who controls the underlying implementation
    /// of a G-UNI pool. For most all pools either this contract address or the zero address will
    /// be the proxyAdmin. If the admin is the zero address the pool's implementation is naturally
    /// no longer upgradable (no one owns the zero address).
    /// @param pool address of the G-UNI pool
    /// @return address that controls the G-UNI implementation (has power to upgrade it)
    function poolProxyAdmin(address pool) public view returns (address) {
        return IEIP173Proxy(pool).proxyAdmin();
    }

    /// @notice isPoolImmutable checks if a certain G-UNI pool is "immutable" i.e.
    /// that the proxyAdmin is the zero address and thus the underlying implementation
    /// cannot be upgraded. Immutable pools are more trustless.
    /// @param pool address of the G-UNI pool
    /// @return bool signaling if pool is immutable (true) or not (false)
    function isPoolImmutable(address pool) external view returns (bool) {
        return address(0) == poolProxyAdmin(pool);
    }

    /// @notice getTokenOrder helper method that sorts token addresses as Uniswap pools
    /// would (lexigraphically ascending order of hex address)
    /// @param tokenA one of the tokens in uniswap pair
    /// @param tokenB other token in uniswap pair
    /// @return token0 the "first" token in the uniswap pair
    /// @return token1 the "second" token in the uniswap pair
    function getTokenOrder(address tokenA, address tokenB)
        public
        pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, "same token");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "no address zero");
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
