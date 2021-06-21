// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import {GUni} from "./GUni.sol";
import {Gelatofied} from "./Gelatofied.sol";
import {OwnableUninitialized} from "./OwnableUninitialized.sol";
import {
    Initializable
} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @dev Single Global upgradeable state var storage base: APPEND ONLY
/// @dev Add all inherited contracts with state vars here: APPEND ONLY
// solhint-disable-next-line max-states-count
abstract contract GUniPoolStaticStorage is
    GUni, /* // XXXX DONT MODIFY ORDERING XXXX*/
    Gelatofied,
    OwnableUninitialized,
    Initializable,
    ReentrancyGuard
    // APPEND ADDITIONAL BASE WITH STATE VARS HERE
    // XXXX DONT MODIFY ORDERING XXXX
{
    address public immutable deployer;

    IUniswapV3Pool public immutable pool;
    IERC20 public immutable token0;
    IERC20 public immutable token1;

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

    constructor(IUniswapV3Pool _pool, address payable _gelato)
        Gelatofied(_gelato)
    {
        deployer = msg.sender;

        pool = _pool;
        token0 = IERC20(_pool.token0());
        token1 = IERC20(_pool.token1());
    }

    function initialize(
        int24 _lowerTick_,
        int24 _upperTick_,
        address _owner_
    ) external initializer {
        require(msg.sender == deployer, "only deployer");
        gelatoSlippageInterval = 5 minutes; // default: last five minutes;
        gelatoSlippageBPS = 500; // default: 5% slippage
        gelatoWithdrawBPS = 100; // default: only auto withdraw if tx fee is lt 1% withdrawn
        gelatoRebalanceBPS = 1000; // default: only rebalance if tx fee is lt 10% reinvested
        adminTreasury = _owner_; // default: treasury is admin

        lowerTick = _lowerTick_;
        upperTick = _upperTick_;

        _owner = _owner_;
    }

    function updateAdminTreasury(address newTreasury) external onlyOwner {
        emit UpdateAdminTreasury(adminTreasury, newTreasury);
        adminTreasury = newTreasury;
    }

    function updateAdminFee(uint16 newFeeBPS) external onlyOwner {
        require(newFeeBPS <= 10000, "BPS"); /// Q: enforce a lower max on the admin fee ???
        emit UpdateAdminFee(adminFeeBPS, newFeeBPS);
        adminFeeBPS = newFeeBPS;
    }

    function updateGelatoParams(
        uint16 newRebalanceBPS,
        uint16 newWithdrawBPS,
        uint16 newSlippageBPS,
        uint32 newSlippageInterval
    ) external onlyOwner {
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
