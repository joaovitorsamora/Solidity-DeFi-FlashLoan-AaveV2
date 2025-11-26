// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ISwapper {
    function swapExactInput(
        address srcToken,
        address dstToken,
        uint256 amountIn,
        uint256 amountOutMin
    ) external returns (uint256);
}
