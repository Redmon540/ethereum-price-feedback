// SPDX-License-Identifier: MIT
pragma solidity >0.5.16;

interface UniswapPriceOracleInterface {
    function update() external;

    function consult(address token) external view returns (uint256 amountOut);
}
