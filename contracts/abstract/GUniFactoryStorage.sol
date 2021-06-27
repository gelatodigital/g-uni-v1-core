//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {IGUniFactoryStorage} from "../interfaces/IGUniFactoryStorage.sol";
import {OwnableUninitialized} from "./OwnableUninitialized.sol";
import {
    Initializable
} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

// solhint-disable-next-line max-states-count
contract GUniFactoryStorage is
    OwnableUninitialized, /* XXXX DONT MODIFY ORDERING XXXX */
    Initializable,
    IGUniFactoryStorage
    // APPEND ADDITIONAL BASE WITH STATE VARS BELOW:
    // XXXX DONT MODIFY ORDERING XXXX
{
    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX
    struct ConstructorParams {
        address owner;
        address implementation;
    }

    ConstructorParams internal _constructorParams;

    address public immutable override deployer;
    address public immutable factory;
    address public poolImplementation;
    /// @notice isPoolCreator maps any address that has deployed a G-UNI pool to true
    mapping(address => bool) public isPoolCreator;
    /// @notice isVerifiedCreator maps any address to true that Gelato
    /// has vetted as "trusted" G-UNI manager
    mapping(address => bool) public isVerifiedCreator;
    // APPPEND ADDITIONAL STATE VARS BELOW:
    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX

    event UpdatePoolImplementation(
        address previousImplementation,
        address newImplementation
    );

    event UpdateVerifyCreator(address poolCreator, bool isVerified);

    constructor(address _uniswapFactory) {
        factory = _uniswapFactory;
        deployer = msg.sender;
    }

    function initialize(address _implementation, address _manager_)
        external
        override
        initializer
    {
        require(msg.sender == deployer, "only deployer");
        poolImplementation = _implementation;
        _manager = _manager_;
    }

    /// @notice used in deployment of GUniEIP173Proxy (see GUniEIP173Proxy.sol constructor)
    function getDeployProps()
        external
        view
        override
        returns (address, address)
    {
        return (_constructorParams.owner, _constructorParams.implementation);
    }

    function verifyPoolCreator(address poolCreator) external onlyManager {
        emit UpdateVerifyCreator(poolCreator, true);
        isVerifiedCreator[poolCreator] = true;
    }

    function unverifyPoolCreator(address poolCreator) external onlyManager {
        emit UpdateVerifyCreator(poolCreator, false);
        isVerifiedCreator[poolCreator] = false;
    }

    function setPoolImplementation(address nextImplementation)
        external
        onlyManager
    {
        emit UpdatePoolImplementation(poolImplementation, nextImplementation);
        poolImplementation = nextImplementation;
    }
}
