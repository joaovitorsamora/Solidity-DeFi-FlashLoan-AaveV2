// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./MockERC20.sol";

contract MockSwapper {
    // preços: src => dst => price * 1e18
    mapping(address => mapping(address => uint256)) public price;

    function setPrice(address src, address dst, uint256 p) external {
        price[src][dst] = p;
    }

    function swapExactInput(
        address src,
        address dst,
        uint256 amountIn,
        uint256 minOut
    ) external returns (uint256 amountOut) {
        require(price[src][dst] > 0, "no price");

        // recebe o token de quem chamou
        MockERC20(src).transferFrom(msg.sender, address(this), amountIn);

        // calcula a saída
        amountOut = (amountIn * price[src][dst]) / 1e18;
        require(amountOut >= minOut, "slippage");

        // paga em dst
        MockERC20(dst).mint(msg.sender, amountOut);
    }
}
