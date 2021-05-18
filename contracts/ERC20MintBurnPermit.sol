//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

// solhint-disable-next-line max-states-count
abstract contract ERC20MintBurnPermit {
    // solhint-disable const-name-snakecase
    string public constant name = "Gelato Uniswap V3 WETH/DAI LP";
    string public constant symbol = "gUNIV3";
    uint8 public constant decimals = 18;
    // solhint-enable const-name-snakecase

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
    // solhint-disable-next-line var-name-mixedcase
    bytes32 public immutable DOMAIN_SEPARATOR;

    uint256 internal _totalSupply;
    mapping(address => uint256) private _balanceOf;
    mapping(address => mapping(address => uint256)) private _allowance;
    mapping(address => uint256) private _nonces;

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor() {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    // solhint-disable-next-line max-line-length
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool) {
        if (_allowance[_from][msg.sender] != type(uint256).max)
            _allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // solhint-disable-next-line not-rely-on-time
        require(deadline >= block.timestamp, "EXPIRED");
        bytes32 digest =
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            spender,
                            value,
                            _nonces[owner]++,
                            deadline
                        )
                    )
                )
            );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(
            recoveredAddress != address(0) && recoveredAddress == owner,
            "ERC20MintBurnPermit: INVALID_SIGNATURE"
        );
        _approve(owner, spender, value);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address _account) external view returns (uint256) {
        return _balanceOf[_account];
    }

    function allowance(address _owner, address _spender)
        external
        view
        returns (uint256)
    {
        return _allowance[_owner][_spender];
    }

    function nonces(address _account) external view returns (uint256) {
        return _nonces[_account];
    }

    function _mint(address _to, uint256 _value) internal {
        _totalSupply += _value;
        _balanceOf[_to] += _value;
        emit Transfer(address(0), _to, _value);
    }

    function _burn(address _from, uint256 _value) internal {
        _balanceOf[_from] -= _value;
        _totalSupply -= _value;
        emit Transfer(_from, address(0), _value);
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 _value
    ) private {
        _allowance[_owner][_spender] = _value;
        emit Approval(_owner, _spender, _value);
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _value
    ) private {
        _balanceOf[_from] -= _value;
        _balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
    }
}
