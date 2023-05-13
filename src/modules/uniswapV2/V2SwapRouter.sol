// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {HelperLibrary} from "./Library.sol";
import {RouterImmutables} from "../../base/RouterImmutables.sol";
import {PeripheryPayments} from "../../base/PeripheryPayments.sol";
import {PeripheryPermit2} from "../../base/PeripheryPermit2.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

/// Router for Uniswap v2 Trades
abstract contract V2SwapRouter is RouterImmutables, PeripheryPermit2 {
    error TooLittleReceived();
    error TooMuchRequested();
    error InvalidPath();

    function _swap(
        address[] calldata path,
        address recipient,
        address pair
    ) private {
        unchecked {
            if (path.length < 2) revert InvalidPath();

            (address token0, ) = HelperLibrary.sortTokens(path[0], path[1]);
            uint256 finalPairIndex = path.length - 1;
            uint256 penultimatePairIndex = finalPairIndex - 1;

            for (uint256 i; i < finalPairIndex; i++) {
                (address input, address output) = (path[i], path[i + 1]);
                (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair)
                    .getReserves();
                (uint256 reserveInput, uint256 reserveOutput) = input == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);
                uint256 amountInput = ERC20(input).balanceOf(pair) -
                    reserveInput;
                uint256 amountOutput = HelperLibrary.getAmountOut(
                    amountInput,
                    reserveInput,
                    reserveOutput
                );
                (uint256 amount0Out, uint256 amount1Out) = input == token0
                    ? (uint256(0), amountOutput)
                    : (amountOutput, uint256(0));
                address nextPair;
                (nextPair, token0) = i < penultimatePairIndex
                    ? HelperLibrary.pairAndToken0For(
                        UNISWAP_V2_FACTORY,
                        UNISWAP_V2_PAIR_INIT_CODE_HASH,
                        output,
                        path[i + 2]
                    )
                    : (recipient, address(0));
                IUniswapV2Pair(pair).swap(
                    amount0Out,
                    amount1Out,
                    nextPair,
                    new bytes(0)
                );
                pair = nextPair;
            }
        }
    }

    /// @notice Performs a Uniswap v2 exact input swap
    function v2SwapExactInput(
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address[] calldata path,
        address payer
    ) internal {
        address firstPair = HelperLibrary.pairFor(
            UNISWAP_V2_FACTORY,
            UNISWAP_V2_PAIR_INIT_CODE_HASH,
            path[0],
            path[1]
        );
        if (
            amountIn != 0 // amountIn of 0 to signal that the pair already has the tokens
        ) {
            payOrPermit2Transfer(path[0], payer, firstPair, amountIn);
        }

        ERC20 tokenOut = ERC20(path[path.length - 1]);
        uint256 balanceBefore = tokenOut.balanceOf(recipient);

        _swap(path, recipient, firstPair);

        uint256 amountOut = tokenOut.balanceOf(recipient) - balanceBefore;

        if (amountOut < amountOutMinimum) revert TooLittleReceived();
    }

    /// @notice Performs a Uniswap v2 exact output swap
    /// @param recipient The recipient of the output tokens
    /// @param amountOut The amount of output tokens to receive for the trade
    /// @param amountInMaximum The maximum desired amount of input tokens
    /// @param path The path of the trade as an array of token addresses
    /// @param payer The address that will be paying the input
    function v2SwapExactOutput(
        address recipient,
        uint256 amountOut,
        uint256 amountInMaximum,
        address[] calldata path,
        address payer
    ) internal {
        (uint256 amountIn, address firstPair) = HelperLibrary
            .getAmountInMultihop(
                UNISWAP_V2_FACTORY,
                UNISWAP_V2_PAIR_INIT_CODE_HASH,
                amountOut,
                path
            );
        if (amountIn > amountInMaximum) revert TooMuchRequested();

        payOrPermit2Transfer(path[0], payer, firstPair, amountIn);
        _swap(path, recipient, firstPair);
    }
}
