// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

// source: https://github.com/mudgen/diamond-3/blob/b009cd08b7822bad727bbcc47aa1b50d8b50f7f0/contracts/facets/OwnershipFacet.sol#L1

import "../../libraries/standard/LibDiamond.sol";
import "../../interfaces/standard/IERC173.sol";

contract OwnershipFacet is IERC173 {
    function transferOwnership(address _newOwner) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_newOwner);
    }

    function owner() external view override returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }
}
