pragma solidity 0.8.12;

import "./dependencies/SafeERC20.sol";
import "./interfaces/IDDLocker.sol";
import "./interfaces/IEarner.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ILpDepositor.sol";
import "./interfaces/IMasterChef.sol";

contract IncentiveEarner is IEarner {
    using SafeERC20 for IERC20;

    address public incentives;
    address public owner;
    address public constant chef = 0x3eB63cff72f8687f8DE64b2f0e40a5B95302D028;
    address public constant lpDepositor = 0x8189F0afdBf8fE6a9e13c69bA35528ac6abeB1af;
    address public constant lpToken = 0xbFa075679a6c47D619269F854adD50C965d5cC64;
    address public constant pool = 0x6B46dFaC1E46f059cea6C0a2D7642d58e8BE71F8;
    address public constant epx = 0xAf41054C1487b0e5E2B9250C0332eCBCe6CE9d71;
    address public constant ddd = 0x84c97300a190676a19D1E13115629A11f8482Bd1;
    address public constant locker = 0x51133C54b7bb6CC89DaC86B73c75B1bf98070e0d;

    constructor() {
        // set to prevent the implementation contract from being initialized
        incentives = address(0xdead);
    }

    function initialize(address _account) external override {
        require(incentives == address(0));
        incentives = msg.sender;
        owner = _account;
        IMasterChef(chef).setClaimReceiver(address(this), _account);
        IERC20(lpToken).approve(msg.sender, type(uint256).max);
        IERC20(ddd).approve(locker, type(uint256).max);
    }

    function deposit(uint256 _amount) external override {
        require(msg.sender == incentives);
        IMasterChef(chef).deposit(incentives, _amount);
    }

    function withdraw(uint256 _amount) external override {
        require(msg.sender == incentives);
        IMasterChef(chef).withdraw(incentives, _amount);
    }

    function claim_dotdot(uint256 _maxBondAmount) external override {
        require(msg.sender == incentives);
        address[] memory tokens = new address[](1);
        tokens[0] = pool;
        ILpDepositor(lpDepositor).claim(address(this), tokens, _maxBondAmount);
        uint256 amount = IERC20(epx).balanceOf(address(this));
        if (amount > 0) {
            IERC20(epx).safeTransfer(owner, amount);
        }
        amount = IERC20(ddd).balanceOf(address(this));
        if (amount > 0) {
            IDDLocker(locker).lock(incentives, amount/10, 16);
            IERC20(ddd).safeTransfer(owner, amount - amount/10);
        }
    }

    function claim_extra() external override {
        require(msg.sender == incentives);
        ILpDepositor(lpDepositor).claimExtraRewards(owner, pool);
    }
}
