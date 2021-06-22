// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import {LibDiamond} from "../../libraries/standard/LibDiamond.sol";
import {LibGUni} from "../gUni/LibGUni.sol";

abstract contract ControlFacet {
    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    modifier onlyManager() {
        LibGUni.enforceIsGUniManager();
        _;
    }
}
