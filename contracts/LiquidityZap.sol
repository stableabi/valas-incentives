pragma solidity 0.8.12;

import "./dependencies/SafeERC20.sol";
import "./interfaces/ICakeLp.sol";
import "./interfaces/IDDLpDepositor.sol";
import "./interfaces/IEpsPool.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IIncentives.sol";

contract LiquidityZap {
    using SafeERC20 for IERC20;

    address public constant cakeLpToken = 0x829F540957DFC652c4466a7F34de611E172e64E8;
    address public constant epsLpToken = 0x6B46dFaC1E46f059cea6C0a2D7642d58e8BE71F8;
    address public constant epsPool = 0xCb13a17e54a93cEFD382886C4cFd735dbe1fFBFb;
    address public constant ddLpToken = 0xbFa075679a6c47D619269F854adD50C965d5cC64;
    address public constant lpDepositor = 0x8189F0afdBf8fE6a9e13c69bA35528ac6abeB1af;
    address public constant wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant valas = 0xB1EbdD56729940089Ecc3aD0BBEEB12b6842ea6F;

    address public immutable incentives;

    constructor (address _incentives) {
        incentives = _incentives;
        IERC20(epsLpToken).approve(lpDepositor, type(uint256).max);
        IERC20(ddLpToken).approve(_incentives, type(uint256).max);
        IERC20(wbnb).approve(epsPool, type(uint256).max);
        IERC20(valas).approve(epsPool, type(uint256).max);
    }

    function _deposit(address _account, uint256 _amount) internal {
        IDDLpDepositor(lpDepositor).deposit(address(this), epsLpToken, _amount);
        IIncentives(incentives).deposit(_account, _amount);
    }

    // Deposit Ellipsis LP token
    function deposit(address _account, uint256 _amount) external {
        IERC20(epsLpToken).safeTransferFrom(msg.sender, address(this), _amount);
        _deposit(_account, _amount);
    }

    // Migrate liquidity from Pancakeswap to Ellipsis -> DotDot -> Incentives
    function migrate(address _account, uint256 _amount, uint256 _minValas, uint256 _minBnb, uint256 _minLp, uint256 _deadline) external {
        require(block.timestamp <= _deadline);
        IERC20(cakeLpToken).safeTransferFrom(msg.sender, cakeLpToken, _amount);
        (uint256 valasAmount, uint256 bnbAmount) = ICakeLp(cakeLpToken).burn(address(this));
        require(valasAmount >= _minValas && bnbAmount >= _minBnb);
        uint256[2] memory amounts = [valasAmount, bnbAmount];
        uint256 amount = IEpsPool(epsPool).add_liquidity(amounts, _minLp, false, address(this));
        _deposit(_account, amount);
    }
}
