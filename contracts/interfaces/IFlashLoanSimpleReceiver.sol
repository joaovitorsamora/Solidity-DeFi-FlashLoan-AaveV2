// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface IFlashLoanSimpleReceiver {
    /**
     * @dev Called by the pool after transferring the flash-loaned amount to the receiver
     * @param asset The address of the asset being flash-borrowed
     * @param amount The amount flash-borrowed
     * @param premium The fee to be paid for the flash loan
     * @param initiator The address that initiated the flash loan
     * @param params Additional params passed from the pool
     * @return True if operation succeeded and funds will be returned to the pool
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}
