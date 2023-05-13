// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {V2SwapRouter} from "./modules/uniswapV2/V2SwapRouter.sol";
import {V3SwapRouter} from "./modules/uniswapV3/V3SwapRouter.sol";
import {BytesLib} from "./utils/BytesLib.sol";
import {PeripheryPayments} from "./base/PeripheryPayments.sol";
import {RouterImmutables} from "./base/RouterImmutables.sol";
// import {Callbacks} from "../base/Callbacks.sol";
import {Commands} from "./utils/Commands.sol";
import {LockAndMsgSender} from "./LockAndMsgSender.sol";
import {ERC721} from "solmate/src/tokens/ERC721.sol";
import {ERC1155} from "solmate/src/tokens/ERC1155.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

/// @title Decodes and Executes Commands
/// @notice Called by the DefiRouter contract to efficiently decode and execute a singular command
abstract contract Dispatcher is
    PeripheryPayments,
    V2SwapRouter,
    V3SwapRouter,
    LockAndMsgSender
{
    using BytesLib for bytes;

    error InvalidCommandType(uint256 commandType);
    error BalanceTooLow();

    /// @notice Decodes and executes the given command with the given inputs
    /// @param commandType The command type to execute
    /// @param inputs The inputs to execute the command with
    /// @dev 2 masks are used to enable use of a nested-if statement in execution for efficiency reasons
    /// @return success True on success of the command, false on failure
    /// @return output The outputs or error messages, if any, from the command
    function dispatch(
        bytes1 commandType,
        bytes calldata inputs
    ) internal returns (bool success, bytes memory output) {
        uint256 command = uint8(commandType & Commands.COMMAND_TYPE_MASK);

        success = true;
        // V3 boundry
        if (command < Commands.FIRST_IF_BOUNDARY) {
            if (command == Commands.V3_SWAP_EXACT_IN) {
                // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool))
                address recipient;
                uint256 amountIn;
                uint256 amountOutMin;
                bool payerIsUser;
                assembly {
                    recipient := calldataload(inputs.offset)
                    amountIn := calldataload(add(inputs.offset, 0x20))
                    amountOutMin := calldataload(add(inputs.offset, 0x40))
                    // 0x60 offset is the path, decoded below
                    payerIsUser := calldataload(add(inputs.offset, 0x80))
                }
                bytes calldata path = inputs.toBytes(3);
                address payer = payerIsUser ? lockedBy : address(this);
                v3SwapExactInput(
                    map(recipient),
                    amountIn,
                    amountOutMin,
                    path,
                    payer
                );
            } else if (command == Commands.V3_SWAP_EXACT_OUT) {
                // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool))
                address recipient;
                uint256 amountOut;
                uint256 amountInMax;
                bool payerIsUser;
                assembly {
                    recipient := calldataload(inputs.offset)
                    amountOut := calldataload(add(inputs.offset, 0x20))
                    amountInMax := calldataload(add(inputs.offset, 0x40))
                    // 0x60 offset is the path, decoded below
                    payerIsUser := calldataload(add(inputs.offset, 0x80))
                }
                bytes calldata path = inputs.toBytes(3);
                address payer = payerIsUser ? lockedBy : address(this);
                v3SwapExactOutput(
                    map(recipient),
                    amountOut,
                    amountInMax,
                    path,
                    payer
                );
            } else if (command == Commands.PERMIT2_TRANSFER_FROM) {
                // equivalent: abi.decode(inputs, (address, address, uint160))
                address token;
                address recipient;
                uint160 amount;
                assembly {
                    token := calldataload(inputs.offset)
                    recipient := calldataload(add(inputs.offset, 0x20))
                    amount := calldataload(add(inputs.offset, 0x40))
                }
                permit2TransferFrom(token, lockedBy, map(recipient), amount);
            } else if (command == Commands.PERMIT2_PERMIT_BATCH) {
                (IAllowanceTransfer.PermitBatch memory permitBatch, ) = abi
                    .decode(inputs, (IAllowanceTransfer.PermitBatch, bytes));
                bytes calldata data = inputs.toBytes(1);
                PERMIT2.permit(lockedBy, permitBatch, data);
            } else if (command == Commands.SWEEP) {
                // equivalent:  abi.decode(inputs, (address, address, uint256))
                address token;
                address recipient;
                uint160 amountMin;
                assembly {
                    token := calldataload(inputs.offset)
                    recipient := calldataload(add(inputs.offset, 0x20))
                    amountMin := calldataload(add(inputs.offset, 0x40))
                }
                PeripheryPayments.sweep(token, map(recipient), amountMin);
            } else if (command == Commands.TRANSFER) {
                // equivalent:  abi.decode(inputs, (address, address, uint256))
                address token;
                address recipient;
                uint256 value;
                assembly {
                    token := calldataload(inputs.offset)
                    recipient := calldataload(add(inputs.offset, 0x20))
                    value := calldataload(add(inputs.offset, 0x40))
                }
                PeripheryPayments.pay(token, map(recipient), value);
            } else if (command == Commands.PAY_PORTION) {
                // equivalent:  abi.decode(inputs, (address, address, uint256))
                address token;
                address recipient;
                uint256 bips;
                assembly {
                    token := calldataload(inputs.offset)
                    recipient := calldataload(add(inputs.offset, 0x20))
                    bips := calldataload(add(inputs.offset, 0x40))
                }
                PeripheryPayments.payPortion(token, map(recipient), bips);
            } else {
                revert InvalidCommandType(command);
            }
        } else {
            // V2 boundry
            if (command == Commands.V2_SWAP_EXACT_IN) {
                // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool))
                address recipient;
                uint256 amountIn;
                uint256 amountOutMin;
                bool payerIsUser;
                assembly {
                    recipient := calldataload(inputs.offset)
                    amountIn := calldataload(add(inputs.offset, 0x20))
                    amountOutMin := calldataload(add(inputs.offset, 0x40))
                    // 0x60 offset is the path, decoded below
                    payerIsUser := calldataload(add(inputs.offset, 0x80))
                }
                address[] calldata path = inputs.toAddressArray(3);
                address payer = payerIsUser ? lockedBy : address(this);
                v2SwapExactInput(
                    map(recipient),
                    amountIn,
                    amountOutMin,
                    path,
                    payer
                );
            } else if (command == Commands.V2_SWAP_EXACT_OUT) {
                // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool))
                address recipient;
                uint256 amountOut;
                uint256 amountInMax;
                bool payerIsUser;
                assembly {
                    recipient := calldataload(inputs.offset)
                    amountOut := calldataload(add(inputs.offset, 0x20))
                    amountInMax := calldataload(add(inputs.offset, 0x40))
                    // 0x60 offset is the path, decoded below
                    payerIsUser := calldataload(add(inputs.offset, 0x80))
                }
                address[] calldata path = inputs.toAddressArray(3);
                address payer = payerIsUser ? lockedBy : address(this);
                v2SwapExactOutput(
                    map(recipient),
                    amountOut,
                    amountInMax,
                    path,
                    payer
                );
            } else if (command == Commands.PERMIT2_PERMIT) {
                // equivalent: abi.decode(inputs, (IAllowanceTransfer.PermitSingle, bytes))
                IAllowanceTransfer.PermitSingle calldata permitSingle;
                assembly {
                    permitSingle := inputs.offset
                }
                bytes calldata data = inputs.toBytes(6); // PermitSingle takes first 6 slots (0..5)
                PERMIT2.permit(lockedBy, permitSingle, data);
            } else if (command == Commands.WRAP_ETH) {
                // equivalent: abi.decode(inputs, (address, uint256))
                address recipient;
                uint256 amountMin;
                assembly {
                    recipient := calldataload(inputs.offset)
                    amountMin := calldataload(add(inputs.offset, 0x20))
                }
                PeripheryPayments.wrapETH(map(recipient), amountMin);
            } else if (command == Commands.UNWRAP_WETH) {
                // equivalent: abi.decode(inputs, (address, uint256))
                address recipient;
                uint256 amountMin;
                assembly {
                    recipient := calldataload(inputs.offset)
                    amountMin := calldataload(add(inputs.offset, 0x20))
                }
                PeripheryPayments.unwrapWETH9(map(recipient), amountMin);
            } else if (command == Commands.PERMIT2_TRANSFER_FROM_BATCH) {
                IAllowanceTransfer.AllowanceTransferDetails[]
                    memory batchDetails = abi.decode(
                        inputs,
                        (IAllowanceTransfer.AllowanceTransferDetails[])
                    );
                permit2TransferFrom(batchDetails, lockedBy);
            } else if (command == Commands.BALANCE_CHECK_ERC20) {
                // equivalent: abi.decode(inputs, (address, address, uint256))
                address owner;
                address token;
                uint256 minBalance;
                assembly {
                    owner := calldataload(inputs.offset)
                    token := calldataload(add(inputs.offset, 0x20))
                    minBalance := calldataload(add(inputs.offset, 0x40))
                }
                success = (ERC20(token).balanceOf(owner) >= minBalance);
                if (!success) output = abi.encodePacked(BalanceTooLow.selector);
            } else {
                revert InvalidCommandType(command);
            }
        }
    }

    /// @notice Executes encoded commands along with provided inputs.
    /// @param commands A set of concatenated commands, each 1 byte in length
    /// @param inputs An array of byte strings containing abi encoded inputs for each command
    function execute(
        bytes calldata commands,
        bytes[] calldata inputs
    ) external payable virtual;

    /// @notice Helper function to extract `value` and `data` parameters from input bytes string
    /// @dev The helper assumes that `value` is the first parameter, and `data` is the second
    /// @param inputs The bytes string beginning with value and data parameters
    /// @return value The 256 bit integer value
    /// @return data The data bytes string
    function getValueAndData(
        bytes calldata inputs
    ) internal pure returns (uint256 value, bytes calldata data) {
        assembly {
            value := calldataload(inputs.offset)
        }
        data = inputs.toBytes(1);
    }
}
