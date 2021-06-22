// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

library LibERC20 {
    using SafeMath for uint256;
    
    bytes32 internal constant _ERC_20_STORAGE_POSITION = keccak256(
        // Compatible with pie-smart-pools
        "erc20.storage.location"
    );

    struct ERC20Storage {
        string name;
        string symbol;
        uint256 totalSupply;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
    }

    // Need to include events locally because `emit Interface.Event(params)` does not work
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function setName(string memory _name) internal returns (string memory) {
        LibERC20Storage.erc20Storage().name = _name;
    }

    function setSymbol(string memory _symbol) internal returns (string memory) {
        LibERC20Storage.erc20Storage().symbol = _symbol;
    }
    
    function name() internal view returns (string memory) {
        return LibERC20Storage.erc20Storage().name;
    }

    function symbol() internal view returns (string memory) {
        return LibERC20Storage.erc20Storage().symbol;
    }

    function decimals() internal pure returns (uint8) {
        return 18;
    }
    
    function approve(address _spender, uint256 _amount)
        internal
        returns (bool)
    {
        require(_spender != address(0), "SPENDER_INVALID");
        LibERC20Storage.erc20Storage().allowances[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    function increaseApproval(address _spender, uint256 _amount) internal returns (bool) {
        require(_spender != address(0), "SPENDER_INVALID");
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();
        es.allowances[msg.sender][_spender] = es.allowances[msg.sender][_spender].add(_amount);
        emit Approval(msg.sender, _spender, es.allowances[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval(address _spender, uint256 _amount) internal returns (bool) {
        require(_spender != address(0), "SPENDER_INVALID");
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();
        uint256 oldValue = es.allowances[msg.sender][_spender];
        if (_amount > oldValue) {
        es.allowances[msg.sender][_spender] = 0;
        } else {
        es.allowances[msg.sender][_spender] = oldValue.sub(_amount);
        }
        emit Approval(msg.sender, _spender, es.allowances[msg.sender][_spender]);
        return true;
    }

    function transfer(address _to, uint256 _amount)
        internal
        returns (bool)
    {
        _transfer(msg.sender, _to, _amount);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) internal returns (bool) {
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();
        require(_from != address(0), "FROM_INVALID");

        // Update approval if not set to max uint256
        if (es.allowances[_from][msg.sender] != uint256(-1)) {
        uint256 newApproval = es.allowances[_from][msg.sender].sub(_amount);
        es.allowances[_from][msg.sender] = newApproval;
        emit Approval(_from, msg.sender, newApproval);
        }

        _transfer(_from, _to, _amount);
        return true;
    }
    
    function getAllowance(address _owner, address _spender)
        internal
        view
        returns (uint256)
    {
        return LibERC20Storage.erc20Storage().allowances[_owner][_spender];
    }

    function balanceOf(address _of) internal view returns (uint256) {
        return LibERC20Storage.erc20Storage().balances[_of];
    }

    function totalSupply() internal view returns (uint256) {
        return LibERC20Storage.erc20Storage().totalSupply;
    }
    
    function mint(address _to, uint256 _amount) internal {
        require(_to != address(0), "INVALID_TO_ADDRESS");

        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();

        es.balances[_to] = es.balances[_to].add(_amount);
        es.totalSupply = es.totalSupply.add(_amount);
        emit Transfer(address(0), _to, _amount);
    }

    function burn(address _from, uint256 _amount) internal {
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();

        es.balances[_from] = es.balances[_from].sub(_amount);
        es.totalSupply = es.totalSupply.sub(_amount);
        emit Transfer(_from, address(0), _amount);
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();

        es.balances[_from] = es.balances[_from].sub(_amount);
        es.balances[_to] = es.balances[_to].add(_amount);

        emit Transfer(_from, _to, _amount);
    }

    function erc20Storage() internal pure returns (ERC20Storage storage es) {
        bytes32 position = _ERC_20_STORAGE_POSITION;
        assembly {
        es.slot := position
        }
    }
}
