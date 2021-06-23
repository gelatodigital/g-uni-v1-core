// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import {Gelatofied} from "./Gelatofied.sol";
import {OwnableUninitialized} from "./OwnableUninitialized.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

/// @dev Single Global upgradeable state var storage base: APPEND ONLY
/// @dev Add all inherited contracts with state vars here: APPEND ONLY
/// @dev ERC20Upgradable Includes Initialize
// solhint-disable-next-line max-states-count
abstract contract GUniPoolStaticStorage is
    ERC20Upgradeable, /* XXXX DONT MODIFY ORDERING XXXX */
    ReentrancyGuardUpgradeable,
    OwnableUninitialized,
    Gelatofied
    // APPEND ADDITIONAL BASE WITH STATE VARS BELOW:
    // XXXX DONT MODIFY ORDERING XXXX
{
    // solhint-disable-next-line const-name-snakecase
    uint16 public constant gelatoFeeBPS = 100;

    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX
    int24 public lowerTick;
    int24 public upperTick;

    uint16 public gelatoRebalanceBPS;
    uint16 public gelatoWithdrawBPS;
    uint16 public gelatoSlippageBPS;
    uint32 public gelatoSlippageInterval;

    uint16 public managerFeeBPS;
    address public managerTreasury;

    uint256 public managerBalance0;
    uint256 public managerBalance1;
    uint256 public gelatoBalance0;
    uint256 public gelatoBalance1;

    IUniswapV3Pool public pool;
    IERC20 public token0;
    IERC20 public token1;
    // APPPEND ADDITIONAL STATE VARS BELOW:

    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX
    event UpdateAdminTreasury(
        address oldAdminTreasury,
        address newAdminTreasury
    );

    event UpdateGelatoParams(
        uint16 gelatoRebalanceBPS,
        uint16 gelatoWithdrawBPS,
        uint16 gelatoSlippageBPS,
        uint32 gelatoSlippageInterval
    );

    // solhint-disable-next-line max-line-length
    constructor(address payable _gelato) Gelatofied(_gelato) {} // solhint-disable-line no-empty-blocks

    function initialize(
        string memory _name,
        string memory _symbol,
        address _pool,
        address _token0,
        address _token1,
        uint16 _managerFeeBPS,
        int24 _lowerTick,
        int24 _upperTick,
        address _manager_
    ) external initializer {
        require(_managerFeeBPS <= 10000 - gelatoFeeBPS, "manager BPS");

        // these variables are immutable after initialization
        pool = IUniswapV3Pool(_pool);
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        managerFeeBPS = _managerFeeBPS; // if set to 0 manager can set to non-zero val

        // these variables can be udpated by the manager
        gelatoSlippageInterval = 5 minutes; // default: last five minutes;
        gelatoSlippageBPS = 500; // default: 5% slippage
        gelatoWithdrawBPS = 100; // default: only auto withdraw if tx fee is lt 1% withdrawn
        gelatoRebalanceBPS = 200; // default: only rebalance if tx fee is lt 2% reinvested
        managerTreasury = _manager_; // default: treasury is admin
        lowerTick = _lowerTick;
        upperTick = _upperTick;
        _manager = _manager_;

        // e.g. "Gelato Uniswap V3 USDC/DAI LP" and "G-UNI"
        __ERC20_init(_name, _symbol);
        __ReentrancyGuard_init();
    }

    // solhint-disable-next-line code-complexity
    function updateGelatoParams(
        uint16 newRebalanceBPS,
        uint16 newWithdrawBPS,
        uint16 newSlippageBPS,
        uint32 newSlippageInterval,
        address newTreasury
    ) external onlyManager {
        require(newWithdrawBPS <= 10000, "BPS");
        require(newRebalanceBPS <= 10000, "BPS");
        require(newSlippageBPS <= 10000, "BPS");
        emit UpdateGelatoParams(
            newRebalanceBPS,
            newWithdrawBPS,
            newSlippageBPS,
            newSlippageInterval
        );
        if (newRebalanceBPS != 0) gelatoRebalanceBPS = newRebalanceBPS;
        if (newWithdrawBPS != 0) gelatoWithdrawBPS = newWithdrawBPS;
        if (newSlippageBPS != 0) gelatoSlippageBPS = newSlippageBPS;
        if (newSlippageInterval != 0)
            gelatoSlippageInterval = newSlippageInterval;
        if (newTreasury != address(0)) managerTreasury = newTreasury;
    }

    function setManagerFee(uint16 _managerFeeBPS) external onlyManager {
        require(managerFeeBPS == 0, "fee already initialized");
        require(
            _managerFeeBPS > 0 && _managerFeeBPS <= 10000 - gelatoFeeBPS,
            "manager BPS"
        );
        managerFeeBPS = _managerFeeBPS;
    }

    function renounceOwnership() public virtual override onlyManager {
        managerTreasury = address(0);
        managerFeeBPS = 0;
        managerBalance0 = 0;
        managerBalance1 = 0;
        super.renounceOwnership();
    }

    function getPositionID() external view returns (bytes32 positionID) {
        return _getPositionID();
    }

    function _getPositionID() internal view returns (bytes32 positionID) {
        return keccak256(abi.encodePacked(address(this), lowerTick, upperTick));
    }
}
