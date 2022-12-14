pragma solidity 0.8.12;

import "./interfaces/IDDLpDepositor.sol";
import "./interfaces/IEarner.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IMasterChef.sol";

contract IncentiveEarner is IEarner {
    address public incentives;
    address public owner;
    address public constant chef = 0x3eB63cff72f8687f8DE64b2f0e40a5B95302D028;
    address public constant lpDepositor = 0x8189F0afdBf8fE6a9e13c69bA35528ac6abeB1af;
    address public constant ddLpToken = 0xbFa075679a6c47D619269F854adD50C965d5cC64;
    address public constant epsLpToken = 0x6B46dFaC1E46f059cea6C0a2D7642d58e8BE71F8;

    constructor() {
        // set to prevent the implementation contract from being initialized
        incentives = address(0xdead);
    }

    function initialize(address _account) external override {
        require(incentives == address(0));
        incentives = msg.sender;
        owner = _account;
        IMasterChef(chef).setClaimReceiver(address(this), _account);
        IERC20(ddLpToken).approve(msg.sender, type(uint256).max);
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
        tokens[0] = epsLpToken;
        IDDLpDepositor(lpDepositor).claim(owner, tokens, _maxBondAmount);
    }

    function claim_extra() external override {
        require(msg.sender == incentives);
        IDDLpDepositor(lpDepositor).claimExtraRewards(owner, epsLpToken);
    }
}
