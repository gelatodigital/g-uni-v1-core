//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IGUniFactory} from "./interfaces/IGUniFactory.sol";
import {IGUniPoolStorage} from "./interfaces/IGUniPoolStorage.sol";
import {GUniFactoryStorage} from "./abstract/GUniFactoryStorage.sol";
import {EIP173Proxy} from "./vendor/proxy/EIP173Proxy.sol";
import {IEIP173Proxy} from "./interfaces/IEIP173Proxy.sol";
import {
    IERC20Metadata
} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract GUniFactory is GUniFactoryStorage, IGUniFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(address _uniswapV3Factory)
        GUniFactoryStorage(_uniswapV3Factory)
    {} // solhint-disable-line no-empty-blocks

    /// @notice createPool creates a new instance of a G-UNI token on a specified
    /// UniswapV3 pool. The msg.sender is the initial manager of the pool and will
    /// forever be associated with the G-UNI pool as it's `deployer`
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

        pool = address(new EIP173Proxy(poolImplementation, address(this), ""));

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
        _deployers.add(msg.sender);
        _pools[msg.sender].add(pool);
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

    function makePoolsImmutable(address[] memory pools) external onlyManager {
        for (uint256 i = 0; i < pools.length; i++) {
            IEIP173Proxy(pools[i]).transferProxyAdmin(address(0));
        }
    }

    /// @notice isPoolImmutable checks if a certain G-UNI pool is "immutable" i.e. that the
    /// proxyAdmin is the zero address and thus the underlying implementation cannot be upgraded
    /// @param pool address of the G-UNI pool
    /// @return bool signaling if pool is immutable (true) or not (false)
    function isPoolImmutable(address pool) external view returns (bool) {
        return address(0) == getProxyAdmin(pool);
    }

    /// @notice getProxyAdmin gets the current address who controls the underlying implementation
    /// of a G-UNI pool. For most all pools either this contract address or the zero address will
    /// be the proxyAdmin. If the admin is the zero address the pool's implementation is naturally
    /// no longer upgradable (no one owns the zero address).
    /// @param pool address of the G-UNI pool
    /// @return address that controls the G-UNI implementation (has power to upgrade it)
    function getProxyAdmin(address pool) public view returns (address) {
        return IEIP173Proxy(pool).proxyAdmin();
    }

    /// @notice getDeployers fetches all addresses that have deployed a G-UNI pool
    /// @return deployers the list of deployer addresses
    function getDeployers() external view returns (address[] memory) {
        uint256 length = numDeployers();
        address[] memory deployers = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            deployers[i] = getDeployer(i);
        }

        return deployers;
    }

    /// @notice getDeployer fetches deployer addresses by index from the deployer EnumerableSet
    /// @param index deployer's index in the EnumerableSet of G-UNI pool deployer addresses
    /// @return address of a G-UNI pool deployer
    function getDeployer(uint256 index) public view returns (address) {
        return _deployers.at(index);
    }

    /// @notice getPools fetches all the G-UNI pool addresses deployed by `deployer`
    /// @param deployer address that has potentially deployed G-UNI pools (can return empty array)
    /// @return pools the list of G-UNI pool addresses deployed by `deployer`
    function getPools(address deployer)
        external
        view
        returns (address[] memory)
    {
        uint256 length = numPools(deployer);
        address[] memory pools = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            pools[i] = getPool(deployer, i);
        }

        return pools;
    }

    /// @notice getPool fetches an address in the EnumerableSet of pools deployed by `deployer`
    /// @param deployer address that has deployed G-UNI pools
    /// @param index index in deployer's EnumerableSet of deployed pool addresses
    /// @return address of a G-UNI pool
    function getPool(address deployer, uint256 index)
        public
        view
        returns (address)
    {
        return _pools[deployer].at(index);
    }

    function numPools(address deployer) public view returns (uint256) {
        return _pools[deployer].length();
    }

    function numDeployers() public view returns (uint256) {
        return _deployers.length();
    }

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
