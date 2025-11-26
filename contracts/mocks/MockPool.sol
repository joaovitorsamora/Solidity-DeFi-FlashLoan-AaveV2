// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

import {IPool} from "../interfaces/IPool.sol";
import {IFlashLoanSimpleReceiver} from "../interfaces/IFlashLoanSimpleReceiver.sol";

contract MockPool is IPool {
    mapping(address => uint256) public liquidity;

    function depositToken(address token, uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        liquidity[token] += amount;
    }

    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata /*params*/,
        uint16 /*referralCode*/
    ) external override {
        require(amount > 0, "borrow zero");
        require(liquidity[asset] >= amount, "insufficient liquidity");

        // send the tokens
        IERC20(asset).transfer(receiverAddress, amount);

        // call receiver
        require(
            IFlashLoanSimpleReceiver(receiverAddress).executeOperation(
                asset,
                amount,
                0, // no premium
                msg.sender,
                ""
            ),
            "executeOperation failed"
        );

        // expect funds back
        uint256 bal = IERC20(asset).balanceOf(address(this));
        require(bal >= liquidity[asset], "flashloan not repaid");
    }

    // Dummy functions for interface
    function supply(address, uint256, address, uint16) external override {}
    function withdraw(address, uint256, address) external pure override returns (uint256) { return 0; }
    function borrow(address, uint256, uint256, uint16, address) external override {}
    function repay(address, uint256, uint256, address) external pure override returns (uint256) { return 0; }
}
