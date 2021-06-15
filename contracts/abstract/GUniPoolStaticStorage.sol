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

    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX
    uint16 internal _maxSlippageBPS;
    uint16 internal _adminFeeBPS;
    uint16 internal _rebalanceFeeBPS;
    uint16 internal _autoWithdrawFeeBPS;
    int24 internal _lowerTick;
    int24 internal _upperTick;
    uint32 internal _observationSeconds;
    address internal _treasury;

    uint256 internal _adminBalanceToken0;
    uint256 internal _adminBalanceToken1;
    // APPPEND ADDITIONAL STATE VARS BELOW:

    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX
    event UpdateAdminParams(
        uint32 observationSeconds,
        uint16 maxSlippageBPS,
        uint16 adminFeeBPS,
        uint16 rebalanceFeeBPS,
        uint16 autoWithdrawFeeBPS,
        address treasury
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
        _observationSeconds = 5 minutes; // default: last five minutes;
        _maxSlippageBPS = 500; // default: 5% slippage
        _autoWithdrawFeeBPS = 100; // default: only auto withdraw if tx fee is lt 1% withdrawn
        _rebalanceFeeBPS = 1000; // default: only rebalance if tx fee is lt 10% reinvested
        _treasury = _owner_; // default: treasury is admin

        _lowerTick = _lowerTick_;
        _upperTick = _upperTick_;

        _owner = _owner_;
    }

    function updateAdminParams(
        uint32 newObservationSeconds,
        uint16 newMaxSlippageBPS,
        uint16 newAdminFeeBPS,
        uint16 newRebalanceFeeBPS,
        uint16 newWithdrawFeeBPS,
        address newTreasury
    ) external onlyOwner {
        require(newMaxSlippageBPS <= 10000, "BPS");
        require(newAdminFeeBPS <= 10000, "BPS");
        require(newWithdrawFeeBPS <= 10000, "BPS");
        require(newRebalanceFeeBPS <= 10000, "BPS");
        emit UpdateAdminParams(
            newObservationSeconds,
            newMaxSlippageBPS,
            newAdminFeeBPS,
            newRebalanceFeeBPS,
            newWithdrawFeeBPS,
            newTreasury
        );
        _adminFeeBPS = newAdminFeeBPS;
        _rebalanceFeeBPS = newRebalanceFeeBPS;
        _autoWithdrawFeeBPS = newWithdrawFeeBPS;
        _observationSeconds = newObservationSeconds;
        _maxSlippageBPS = newMaxSlippageBPS;
        _treasury = newTreasury;
    }

    function lowerTick() external view returns (int24) {
        return _lowerTick;
    }

    function upperTick() external view returns (int24) {
        return _upperTick;
    }

    function getPositionID() external view returns (bytes32 positionID) {
        return _getPositionID();
    }

    function _getPositionID() internal view returns (bytes32 positionID) {
        return
            keccak256(abi.encodePacked(address(this), _lowerTick, _upperTick));
    }
}
