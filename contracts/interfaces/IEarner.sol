pragma solidity 0.8.12;

interface IEarner {
    function initialize(address _lpToken, address _account) external;
    function deposit(uint256 _amount) external;
    function withdraw(uint256 _amount) external;
    function claim_dotdot(uint256 _maxBondAmount) external;
    function claim_extra() external;
}
