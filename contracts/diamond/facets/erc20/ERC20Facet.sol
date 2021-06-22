// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../libraries/standard/LibDiamond.sol";

import "./LibERC20.sol";

contract ERC20Facet is IERC20 {
  using SafeMath for uint256;

  function initialize(
    uint256 _initialSupply,
    string memory _name,
    string memory _symbol
  ) external onlyOwner {

    require(
        bytes(LibERC20.name()).length == 0 &&
        bytes(LibERC20.symbol()).length == 0,
        "ALREADY_INITIALIZED"
    );

    require(
        bytes(_name).length != 0 &&
        bytes(_symbol).length != 0,
        "INVALID_PARAMS"
    );

    LibERC20.setName(_name);
    LibERC20.setSymbol(_symbol);
  }

  function name() external view returns (string memory) {
    return LibERC20.name();
  }

  function symbol() external view returns (string memory) {
    return LibERC20.symbol();
  }

  function decimals() external pure returns (uint8) {
    return LibERC20.decimals();
  }

  function approve(address _spender, uint256 _amount)
    external
    returns (bool)
  {
    return LibERC20.approve(_spender, _amount);
  }

  function increaseApproval(address _spender, uint256 _amount) external returns (bool) {
    return LibERC20.increaseApproval(_spender, _amount);
  }

  function decreaseApproval(address _spender, uint256 _amount) external returns (bool) {
    return LibERC20.decreaseApproval(_spender, _amount);
  }

  function transfer(address _to, uint256 _amount)
    external
    returns (bool)
  {
    return LibERC20.transfer(_to, _amount);
  }

  function transferFrom(
    address _from,
    address _to,
    uint256 _amount
  ) external returns (bool) {
    return LibERC20.transferFrom(_from, _to_ amount);
  }

  function allowance(address _owner, address _spender)
    external
    view
    returns (uint256)
  {
    return LibERC20.allowance(_owner, _spender);
  }

  function balanceOf(address _of) external view returns (uint256) {
    return LibERC20.balanceOf(_of);
  }

  function totalSupply() external view returns (uint256) {
    return LibERC20.totalSupply();
  }

}