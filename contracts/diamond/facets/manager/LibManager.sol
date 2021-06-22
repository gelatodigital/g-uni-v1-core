// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import {TickMath} from "../../../vendor/uniswap/TickMath.sol";
import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library LibManager {
    using SafeERC20 for IERC20;
    using TickMath for int24;

    // solhint-disable-next-line const-name-snakecase
    uint16 constant gelatoFeeBPS = 50;
    
    struct ManagerStorage {
        int24 lowerTick;
        int24 upperTick;

        uint16 gelatoRebalanceBPS;
        uint16 gelatoWithdrawBPS;
        uint16 gelatoSlippageBPS;
        uint32 gelatoSlippageInterval;

        uint16 adminFeeBPS;
        address adminTreasury;
        address manager;

        uint256 adminBalance0;
        uint256 adminBalance1;
        uint256 gelatoBalance0;
        uint256 gelatoBalance1;
    }

    bytes32 private constant _MANAGER_STORAGE =
        keccak256("manager.storage.location");

    function enforceIsGUniManager() internal view {
        require(
            msg.sender == managerStorage().manager,
            "LibDiamond: Must be G-UNI Manager"
        );
    }
    
    function setTicks(int24 _lowerTick, int24 _upperTick) internal {
        LibUniswap.managerStorage().lowerTick = _lowerTick;
        LibUniswap.managerStorage().upperTick = _upperTick;
    }

    function setGelatoRebalanceBPS(uint16 _gelatoRebalanceBPS) internal {
        LibUniswap.managerStorage().gelatoRebalanceBPS = _gelatoRebalanceBPS;
    }

    function setGelatoWithdrawBPS(uint16 _gelatoWithdrawBPS) internal {
        LibUniswap.managerStorage().gelatoWithdrawBPS = _gelatoWithdrawBPS;
    }

    function setGelatoSlippageBPS(uint16 _gelatoSlippageBPS) internal {
        LibUniswap.managerStorage().gelatoSlippageBPS = _gelatoSlippageBPS;
    }

    function setGelatoSlippageInterval(uint32 _gelatoSlippageInterval) internal {
        LibUniswap.managerStorage().gelatoSlippageInterval = _gelatoSlippageInterval;
    }

    function setAdminFeeBPS(uint16 _adminFeeBPS) internal {
        LibUniswap.managerStorage().adminFeeBPS = _adminFeeBPS;
    }

    function setAdminTreasury(address _adminTreasury) internal {
        LibUniswap.managerStorage().adminTreasury = _adminTreasury;
    }

    function setManager(address _manager) internal {
        LibUniswap.managerStorage().manager = _manager;
    }

    function setAdminBalances(uint256 _adminBalance0, uint256 _adminBalance1) internal {
        LibUniswap.managerStorage().adminBalance0 = _adminBalance0;
        LibUniswap.managerStorage().adminBalance1 = _adminBalance1;
    }

    function setGelatoBalances(uint256 _gelatoBalance0, uint256 _gelatoBalance1) internal {
        LibUniswap.managerStorage().gelatoBalance0 = _gelatoBalance0;
        LibUniswap.managerStorage().gelatoBalance1 = _gelatoBalance1;
    }

    function getTicks() internal view returns (int24, int24) {
        return (managerStorage().lowerTick, managerStorage().upperTick);
    }

    function getGelatoRebalanceBPS() internal view returns(uint16) {
        return LibUniswap.managerStorage().gelatoRebalanceBPS;
    }

    function getGelatoWithdrawBPS() internal view returns(uint16) {
        return LibUniswap.managerStorage().gelatoWithdrawBPS;
    }

    function getGelatoSlippageBPS() internal view returns(uint16) {
        return LibUniswap.managerStorage().gelatoSlippageBPS;
    }

    function getGelatoSlippageInterval() internal view returns(uint32) {
        return LibUniswap.managerStorage().gelatoSlippageInterval;
    }

    function getAdminFeeBPS() internal view returns(uint16) {
        return LibUniswap.managerStorage().adminFeeBPS;
    }

    function getAdminTreasury() internal view returns(address) {
        return LibUniswap.managerStorage().adminTreasury;
    }

    function getManager() internal view returns(address) {
        return LibUniswap.managerStorage().manager;
    }

    function getAdminBalances() internal view returns(uint256, uint256) {
        return(LibUniswap.managerStorage().adminBalance0, LibUniswap.managerStorage().adminBalance1);
    }

    function getGelatoBalances() internal view returns(uint256, uint256) {
        return (LibUniswap.managerStorage().gelatoBalance0, LibUniswap.managerStorage().gelatoBalance1);
    }

    function managerStorage()
        internal
        pure
        returns (ManagerStorage storage ads)
    {
        bytes32 position = _MANAGER_STORAGE;
        assembly {
            ads.slot := position
        }
    }
}
