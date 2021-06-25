//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IGUniFactoryStorage {
    function deployer() external view returns (address);

    function initialize(address _owner_) external;

    function getDeployProps() external view returns (address, address);
}
