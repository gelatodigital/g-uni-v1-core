// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import {LibManager} from "./LibManager.sol";
import {ControlFacet} from "../base/ControlFacet.sol";
import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import {Initializable} from "@openzeppelin/contracts-upgradeable/contracts/proxy/utils/Initializable.sol"

contract ManagerFacet {
    
    // Only called once by the factoy, thus we dont need initializable, might still want to add it though
    function initialize(
        int24 _lowerTick,
        int24 _upperTick,
        address _treasury,
        address _manager
    ) external onlyOwner {
        
        LibManager.setGelatoSlippageInterval(5 minutes); // default: last five minutes;
        LibManager.setGelatoSlippageBPS(500); // default: 5% slippage
        LibManager.setGelatoWithdrawBPS(100); // default: only auto withdraw if tx fee is lt 1% withdrawn
        LibManager.setGelatoRebalanceBPS(1000); // default: only rebalance if tx fee is lt 10% reinvested
        
        LibManager.setLowerTick(_lowerTick);
        LibManager.setUpperTick(_upperTick);

        LibManager.setAdminTreasury(_treasury);
        LibManager.setManager(_manager);
    }
    
    function setGelatoRebalanceBPS(uint16 _gelatoRebalanceBPS) external onlyManager {
        LibManager.setGelatoRebalanceBPS(_gelatoRebalanceBPS);
    }

    function setGelatoWithdrawBPS(uint16 _gelatoWithdrawBPS) external onlyManager {
        LibManager.setGelatoWithdrawBPS(_gelatoWithdrawBPS);
    }

    function setGelatoSlippageBPS(uint16 _gelatoSlippageBPS) external onlyManager {
        LibManager.setGelatoSlippageBPS(_gelatoSlippageBPS);
    }

    function setGelatoSlippageInterval(uint32 _gelatoSlippageInterval) external onlyManager {
        LibManager.setGelatoSlippageInterval(_gelatoSlippageInterval);
    }

    function setAdminFeeBPS(uint16 _adminFeeBPS) external onlyManager {
        LibManager.setAdminFeeBPS(_adminFeeBPS);
    }

    function setAdminTreasury(address _adminTreasury) external onlyManager {
        LibManager.setAdminTreasury(_adminTreasury);
    }

}