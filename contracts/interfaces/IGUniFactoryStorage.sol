//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IGUniFactoryStorage {
    function initialize(address _implementation, address _owner_) external;

    function getDeployProps() external view returns (address, address);
}
