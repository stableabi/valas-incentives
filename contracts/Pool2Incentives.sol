pragma solidity 0.8.12;

import "./dependencies/SafeERC20.sol";
import "./interfaces/IDDLocker.sol";
import "./interfaces/IDDLpDepositor.sol";
import "./interfaces/IDDVoting.sol";
import "./interfaces/IEarner.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IIncentives.sol";
import "./interfaces/IMasterChef.sol";

contract Pool2Incentives is IERC20, IIncentives {
    using SafeERC20 for IERC20;

    address public constant chef = 0x3eB63cff72f8687f8DE64b2f0e40a5B95302D028;
    address public constant lpDepositor = 0x8189F0afdBf8fE6a9e13c69bA35528ac6abeB1af;
    address public constant ddlpToken = 0xbFa075679a6c47D619269F854adD50C965d5cC64;
    address public constant epsLpToken = 0x6B46dFaC1E46f059cea6C0a2D7642d58e8BE71F8;
    address public constant locker = 0x51133C54b7bb6CC89DaC86B73c75B1bf98070e0d;
    address public constant voting = 0x5e4b853944f54C8Cb568b25d269Cd297B8cEE36d;
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

    constructor (address _earnerImpl) {
        earnerImpl = _earnerImpl;
    }

    function deposit(address _account, uint256 _amount) external override {
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
        IERC20(ddlpToken).safeTransferFrom(msg.sender, earner, _amount);
    }

    function _withdraw(address _account, uint256 _amount) internal {
        address earner = earners[msg.sender];
        require(earner != address(0));

        // We need to call this first so the earner can withdraw the token from the chef
        IEarner(earner).withdraw(_amount);

        totalSupply -= _amount;
        lpBalance[msg.sender] -= _amount;
        balanceOf[earner] -= _amount;

        IERC20(ddlpToken).safeTransferFrom(earner, _account, _amount);
    }

    // Withdraw DotDot LP token
    function withdraw(address _account, uint256 _amount) external {
        _withdraw(_account, _amount);
    }

    // Withdraw Ellipsis LP token
    function withdraw_eps(address _account, uint256 _amount) external {
        _withdraw(address(this), _amount);
        IDDLpDepositor(lpDepositor).withdraw(_account, epsLpToken, _amount);
    }

    function claimable(address _account) external view returns (uint256 valas, uint256 epx, uint256 ddd, ExtraReward[] memory extra) {
        address earner = earners[_account];
        if (earner != address(0)) {
            address[] memory tokens = new address[](1);
            tokens[0] = address(this);
            uint256[] memory a = IMasterChef(chef).claimableReward(earner, tokens);
            valas = a[0] + IMasterChef(chef).userBaseClaimable(earner);

            tokens[0] = epsLpToken;
            Amounts[] memory b = IDDLpDepositor(lpDepositor).claimable(earner, tokens);
            epx = b[0].epx;
            ddd = b[0].ddd;

            extra = IDDLpDepositor(lpDepositor).claimableExtraRewards(earner, epsLpToken);
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

    function extend_lock(uint256 _amount, uint256 _weeks) external {
        IDDLocker(locker).extendLock(_amount, _weeks, 16);
    }

    function vote(uint256 _amount) external {
        address[] memory tokens = new address[](1);
        tokens[0] = epsLpToken;
        uint256[] memory votes = new uint256[](1);
        votes[0] = _amount;
        IDDVoting(voting).vote(tokens, votes);
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
        IEarner(earner).initialize(_account);
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
