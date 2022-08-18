pragma solidity 0.8.12;

interface IMasterChef {
    function userBaseClaimable(address _user) external view returns (uint256);
    function claimableReward(address _user, address[] calldata _tokens) external view returns (uint256[] memory);
    function setClaimReceiver(address _user, address _receiver) external;
    function deposit(address _token, uint256 _amount) external;
    function withdraw(address _token, uint256 _amount) external;
    function claim(address _user, address[] calldata _tokens) external;
}
