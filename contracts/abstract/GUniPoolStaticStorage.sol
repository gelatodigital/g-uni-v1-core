// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import {Gelatofied} from "./Gelatofied.sol";
import {OwnableUninitialized} from "./OwnableUninitialized.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

/// @dev Single Global upgradeable state var storage base: APPEND ONLY
/// @dev Add all inherited contracts with state vars here: APPEND ONLY
/// @dev ERC20Upgradable Includes Initialize
// solhint-disable-next-line max-states-count
abstract contract GUniPoolStaticStorage is
    ERC20Upgradeable, /* // XXXX DONT MODIFY ORDERING XXXX*/
    Gelatofied,
    OwnableUninitialized,
    ReentrancyGuard
    // APPEND ADDITIONAL BASE WITH STATE VARS HERE
    // XXXX DONT MODIFY ORDERING XXXX
{
    // solhint-disable-next-line const-name-snakecase
    uint16 public constant gelatoFeeBPS = 50;

    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX
    int24 public lowerTick;
    int24 public upperTick;

    uint16 public gelatoRebalanceBPS;
    uint16 public gelatoWithdrawBPS;
    uint16 public gelatoSlippageBPS;
    uint32 public gelatoSlippageInterval;

    uint16 public adminFeeBPS;
    address public adminTreasury;

    uint256 public adminBalance0;
    uint256 public adminBalance1;
    uint256 public gelatoBalance0;
    uint256 public gelatoBalance1;

    IUniswapV3Pool public pool;
    // We can delete token0 and token1 and always query it from pool
    IERC20 public token0;
    IERC20 public token1;
    // APPPEND ADDITIONAL STATE VARS BELOW:

    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX
    event UpdateAdminFee(uint16 oldAdminFeeBPS, uint16 newAdminFeeBPS);

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
        int24 _lowerTick_,
        int24 _upperTick_,
        address _manager_
    ) external initializer {
        gelatoSlippageInterval = 5 minutes; // default: last five minutes;
        gelatoSlippageBPS = 500; // default: 5% slippage
        gelatoWithdrawBPS = 100; // default: only auto withdraw if tx fee is lt 1% withdrawn
        gelatoRebalanceBPS = 200; // default: only rebalance if tx fee is lt 2% reinvested
        adminTreasury = _manager_; // default: treasury is admin

        pool = IUniswapV3Pool(_pool);
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        lowerTick = _lowerTick_;
        upperTick = _upperTick_;

        _manager = _manager_;

        // e.g. Gelato Uniswap V3 INST/ETH LP
        __ERC20_init(_name, _symbol);
    }

    function updateAdminTreasury(address newTreasury) external onlyManager {
        emit UpdateAdminTreasury(adminTreasury, newTreasury);
        adminTreasury = newTreasury;
    }

    function updateAdminFee(uint16 newFeeBPS) external onlyManager {
        require(newFeeBPS <= 9950, "admin fee BPS");
        adminFeeBPS = newFeeBPS;
    }

    function updateGelatoParams(
        uint16 newRebalanceBPS,
        uint16 newWithdrawBPS,
        uint16 newSlippageBPS,
        uint32 newSlippageInterval
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
        gelatoRebalanceBPS = newRebalanceBPS;
        gelatoWithdrawBPS = newWithdrawBPS;
        gelatoSlippageBPS = newSlippageBPS;
        gelatoSlippageInterval = newSlippageInterval;
    }

    function getPositionID() external view returns (bytes32 positionID) {
        return _getPositionID();
    }

    function _getPositionID() internal view returns (bytes32 positionID) {
        return keccak256(abi.encodePacked(address(this), lowerTick, upperTick));
    }
}
