pragma solidity 0.8.12;

interface ICakeLp {
    function burn(address to) external returns (uint amount0, uint amount1);
}
