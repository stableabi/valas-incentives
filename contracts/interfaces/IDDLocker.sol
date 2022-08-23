pragma solidity 0.8.12;

interface IDDLocker {
    function lock(address _user, uint256 _amount, uint256 _weeks) external returns (bool);
    function extendLock(uint256 _amount, uint256 _weeks, uint256 _newWeeks) external returns (bool);
}
