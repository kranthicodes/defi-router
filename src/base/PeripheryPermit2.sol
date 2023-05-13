pragma solidity ^0.8.13;

import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {SafeCast160} from "permit2/src/libraries/SafeCast160.sol";
import "./PeripheryPayments.sol";

/// @title Periphery Payments through Permit2
abstract contract PeripheryPermit2 is PeripheryPayments {
    using SafeCast160 for uint256;

    function approve(
        address token,
        address spender,
        uint160 amount,
        uint48 expiration
    ) public {
        PERMIT2.approve(token, spender, amount, expiration);
    }

    function permit(
        address from,
        IAllowanceTransfer.PermitSingle calldata permitSingle,
        bytes calldata signature
    ) public {
        PERMIT2.permit(from, permitSingle, signature);
    }

    function permit(
        address from,
        IAllowanceTransfer.PermitBatch calldata permitBatch,
        bytes calldata signature
    ) public {
        PERMIT2.permit(from, permitBatch, signature);
    }

    function permit2TransferFrom(
        address token,
        address from,
        address to,
        uint160 amount
    ) public {
        PERMIT2.transferFrom(from, to, amount, token);
    }

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
