// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

// source: https://github.com/mudgen/diamond-3/blob/b009cd08b7822bad727bbcc47aa1b50d8b50f7f0/contracts/facets/DiamondCutFacet.sol#L1

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamond Standard: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/

import "../../interfaces/standard/IDiamondCut.sol";
import "../../libraries/standard/LibDiamond.sol";

contract DiamondCutFacet is IDiamondCut {
    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }
}
