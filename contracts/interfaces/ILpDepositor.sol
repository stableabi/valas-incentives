pragma solidity 0.8.12;

struct Amounts {
    uint256 epx;
    uint256 ddd;
}

struct ExtraReward {
    address token;
    uint256 amount;
}

interface ILpDepositor {
    function claimable(address _user, address[] calldata _tokens) external view returns (Amounts[] memory);
    function claimableExtraRewards(address user, address pool) external view returns (ExtraReward[] memory);
    function claim(address _receiver, address[] calldata _tokens, uint256 _maxBondAmount) external;
    function claimExtraRewards(address _receiver, address pool) external;
}