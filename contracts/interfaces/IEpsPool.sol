pragma solidity 0.8.12;

interface IEpsPool {
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount, bool use_eth, address receiver) external returns (uint256);
}
