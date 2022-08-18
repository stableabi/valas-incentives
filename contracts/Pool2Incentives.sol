pragma solidity 0.8.12;

import "./dependencies/SafeERC20.sol";
import "./interfaces/IEarner.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ILpDepositor.sol";
import "./interfaces/ILpToken.sol";
import "./interfaces/IMasterChef.sol";

contract Pool2Incentives is IERC20 {
    using SafeERC20 for IERC20;

    address public constant chef = 0x3eB63cff72f8687f8DE64b2f0e40a5B95302D028;
    address public constant lpDepositor = 0x8189F0afdBf8fE6a9e13c69bA35528ac6abeB1af;
    address public immutable lpToken;
    address public immutable earnerImpl;
    mapping(address => uint256) public lpBalance;
    mapping(address => address) public earners;

    // ERC20 variables

    string public constant name = "pool2-valas";
    string public constant symbol = "p2-v";
    uint8 public constant decimals = 18;
    uint256 public override totalSupply;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    constructor (address _lpToken, address _earnerImpl) {
        lpToken = _lpToken;
        earnerImpl = _earnerImpl;
    }

    function deposit(address _account, uint256 _amount) external {
        address earner = earners[_account];
        if (earner == address(0)) {
            earner = _deployEarner(_account);
            earners[_account] = earner;
            allowance[earner][chef] = type(uint).max;
        }

        totalSupply += _amount;
        lpBalance[_account] += _amount;
        balanceOf[earner] += _amount;

        IEarner(earner).deposit(_amount);
        IERC20(lpToken).safeTransferFrom(msg.sender, earner, _amount);
    }

    function withdraw(address _account, uint256 _amount) external {
        address earner = earners[msg.sender];
        require(earner != address(0));

        // We need to call this first so the earner can withdraw the token from the chef
        IEarner(earner).withdraw(_amount);

        totalSupply -= _amount;
        lpBalance[msg.sender] -= _amount;
        balanceOf[earner] -= _amount;

        IERC20(lpToken).safeTransferFrom(earner, _account, _amount);
    }

    function claimable(address _account) external view returns (uint256 valas, uint256 epx, uint256 ddd, ExtraReward[] memory extra) {
        address earner = earners[_account];
        if (earner != address(0)) {
            address[] memory tokens = new address[](1);
            tokens[0] = address(this);
            uint256[] memory a = IMasterChef(chef).claimableReward(earner, tokens);
            valas = a[0] + IMasterChef(chef).userBaseClaimable(earner);

            address pool = ILpToken(lpToken).pool();
            tokens[0] = pool;
            Amounts[] memory b = ILpDepositor(lpDepositor).claimable(earner, tokens);
            epx = b[0].epx;
            ddd = b[0].ddd;

            extra = ILpDepositor(lpDepositor).claimableExtraRewards(earner, pool);
        }
    }

    function claim(uint256 _maxBondAmount, bool extra) external {
        claim_valas();
        claim_dotdot(_maxBondAmount);
        if (extra) {
            claim_extra();
        }
    }

    function claim_valas() public {
        address earner = earners[msg.sender];
        require(earner != address(0));

        address[] memory tokens = new address[](1);
        tokens[0] = address(this);
        IMasterChef(chef).claim(earner, tokens);
    }

    function claim_dotdot(uint256 _maxBondAmount) public {
        address earner = earners[msg.sender];
        require(earner != address(0));

        IEarner(earner).claim_dotdot(_maxBondAmount);
    }

    function claim_extra() public {
        address earner = earners[msg.sender];
        require(earner != address(0));

        IEarner(earner).claim_extra();
    }

    function _deployEarner(address _account) internal returns (address earner) {
        // taken from https://solidity-by-example.org/app/minimal-proxy/
        bytes20 targetBytes = bytes20(earnerImpl);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            earner := create(0, clone, 0x37)
        }
        IEarner(earner).initialize(lpToken, _account);
        return earner;
    }

    // ERC20 functions

    function approve(address _spender, uint256 _value) external override returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function _transfer(address _from, address _to, uint256 _value) internal {
        require(balanceOf[_from] >= _value, "Insufficient balance");
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
    }

    function transfer(address _to, uint256 _value) public override returns (bool) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public override returns (bool) {
        require(allowance[_from][msg.sender] >= _value, "Insufficient allowance");
        if (allowance[_from][msg.sender] != type(uint).max) {
            allowance[_from][msg.sender] -= _value;
        }
        _transfer(_from, _to, _value);
        return true;
    }
}
