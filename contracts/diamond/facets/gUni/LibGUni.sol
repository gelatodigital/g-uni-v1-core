// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import {TickMath} from "../../../vendor/uniswap/TickMath.sol";
import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library LibGUni {
    using SafeERC20 for IERC20;
    using TickMath for int24;

    // solhint-disable-next-line const-name-snakecase
    uint16 constant gelatoFeeBPS = 50;
    
    struct GUNIStorage {
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

    bytes32 private constant _GUNI_STORAGE =
        keccak256("guni.storage.location");

    function enforceIsGUniManager() internal view {
        require(
            msg.sender == gUniStorage().manager,
            "LibDiamond: Must be G-UNI Manager"
        );
    }
    
    function setTicks(int24 _lowerTick, int24 _upperTick) internal {
        LibUniswap.gUniStorage().lowerTick = _lowerTick;
        LibUniswap.gUniStorage().upperTick = _upperTick;
    }

    function setGelatoRebalanceBPS(uint16 _gelatoRebalanceBPS) internal {
        LibUniswap.gUniStorage().gelatoRebalanceBPS = _gelatoRebalanceBPS;
    }

    function setGelatoWithdrawBPS(uint16 _gelatoWithdrawBPS) internal {
        LibUniswap.gUniStorage().gelatoWithdrawBPS = _gelatoWithdrawBPS;
    }

    function setGelatoSlippageBPS(uint16 _gelatoSlippageBPS) internal {
        LibUniswap.gUniStorage().gelatoSlippageBPS = _gelatoSlippageBPS;
    }

    function setGelatoSlippageInterval(uint32 _gelatoSlippageInterval) internal {
        LibUniswap.gUniStorage().gelatoSlippageInterval = _gelatoSlippageInterval;
    }

    function setAdminFeeBPS(uint16 _adminFeeBPS) internal {
        LibUniswap.gUniStorage().adminFeeBPS = _adminFeeBPS;
    }

    function setAdminTreasury(address _adminTreasury) internal {
        LibUniswap.gUniStorage().adminTreasury = _adminTreasury;
    }

    function setManager(address _manager) internal {
        LibUniswap.gUniStorage().manager = _manager;
    }

    function setAdminBalances(uint256 _adminBalance0, uint256 _adminBalance1) internal {
        LibUniswap.gUniStorage().adminBalance0 = _adminBalance0;
        LibUniswap.gUniStorage().adminBalance1 = _adminBalance1;
    }

    function setGelatoBalances(uint256 _gelatoBalance0, uint256 _gelatoBalance1) internal {
        LibUniswap.gUniStorage().gelatoBalance0 = _gelatoBalance0;
        LibUniswap.gUniStorage().gelatoBalance1 = _gelatoBalance1;
    }

    function getTicks() internal view returns (int24, int24) {
        return (gUniStorage().lowerTick, gUniStorage().upperTick);
    }

    function getGelatoRebalanceBPS() internal view returns(uint16) {
        return LibUniswap.gUniStorage().gelatoRebalanceBPS;
    }

    function getGelatoWithdrawBPS() internal view returns(uint16) {
        return LibUniswap.gUniStorage().gelatoWithdrawBPS;
    }

    function getGelatoSlippageBPS() internal view returns(uint16) {
        return LibUniswap.gUniStorage().gelatoSlippageBPS;
    }

    function getGelatoSlippageInterval() internal view returns(uint32) {
        return LibUniswap.gUniStorage().gelatoSlippageInterval;
    }

    function getAdminFeeBPS() internal view returns(uint16) {
        return LibUniswap.gUniStorage().adminFeeBPS;
    }

    function getAdminTreasury() internal view returns(address) {
        return LibUniswap.gUniStorage().adminTreasury;
    }

    function getManager() internal view returns(address) {
        return LibUniswap.gUniStorage().manager;
    }

    function getAdminBalances() internal view returns(uint256, uint256) {
        return(LibUniswap.gUniStorage().adminBalance0, LibUniswap.gUniStorage().adminBalance1);
    }

    function getGelatoBalances() internal view returns(uint256, uint256) {
        return (LibUniswap.gUniStorage().gelatoBalance0, LibUniswap.gUniStorage().gelatoBalance1);
    }

    function gUniStorage()
        internal
        pure
        returns (GUNIStorage storage ads)
    {
        bytes32 position = _GUNI_STORAGE;
        assembly {
            ads.slot := position
        }
    }
}
