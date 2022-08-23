pragma solidity 0.8.12;

interface IDDVoting {
    function vote(address[] calldata _tokens, uint256[] memory _votes) external;
}
