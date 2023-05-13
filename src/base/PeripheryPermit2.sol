pragma solidity ^0.8.13;

import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {SafeCast160} from "permit2/src/libraries/SafeCast160.sol";
import "./PeripheryPayments.sol";

/// @title Periphery Payments through Permit2
abstract contract PeripheryPermit2 is PeripheryPayments {
    using SafeCast160 for uint256;

    /// @notice Performs a transferFrom on Permit2
    /// @param token The token to transfer
    /// @param from The address to transfer from
    /// @param to The recipient of the transfer
    /// @param amount The amount to transfer
    function permit2TransferFrom(
        address token,
        address from,
        address to,
        uint160 amount
    ) public {
        PERMIT2.transferFrom(from, to, amount, token);
    }

    /// @notice Performs a batch transferFrom on Permit2
    /// @param batchDetails An array detailing each of the transfers that should occur
    function permit2TransferFrom(
        IAllowanceTransfer.AllowanceTransferDetails[] memory batchDetails,
        address owner
    ) public {
        uint256 batchLength = batchDetails.length;
        for (uint256 i = 0; i < batchLength; ++i) {
            require(
                batchDetails[i].from == owner,
                "Error: FromAddressIsNotOwner"
            );
        }
        PERMIT2.transferFrom(batchDetails);
    }

    /// @notice Either performs a regular payment or transferFrom on Permit2, depending on the payer address
    /// @param token The token to transfer
    /// @param payer The address to pay for the transfer
    /// @param recipient The recipient of the transfer
    /// @param amount The amount to transfer
    function payOrPermit2Transfer(
        address token,
        address payer,
        address recipient,
        uint256 amount
    ) public {
        if (payer == address(this)) pay(token, recipient, amount);
        else permit2TransferFrom(token, payer, recipient, amount.toUint160());
    }
}
