// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

/// @title Uniswap v2 Helper Library
/// @notice Calculates the recipient address for a command
library HelperLibrary {
    error InvalidReserves();
    error InvalidPath();

    /// Calculates the v2 address for a pair without making any external calls
    function pairFor(
        address factory,
        bytes32 initCodeHash,
        address tokenA,
        address tokenB
    ) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = pairForPreSorted(factory, initCodeHash, token0, token1);
    }

    /// Calculates the v2 address for a pair and the pair's token0
    function pairAndToken0For(
        address factory,
        bytes32 initCodeHash,
        address tokenA,
        address tokenB
    ) internal pure returns (address pair, address token0) {
        address token1;
        (token0, token1) = sortTokens(tokenA, tokenB);
        pair = pairForPreSorted(factory, initCodeHash, token0, token1);
    }

    /// Calculates the v2 address for a pair assuming the input tokens are pre-sorted
    function pairForPreSorted(
        address factory,
        bytes32 initCodeHash,
        address token0,
        address token1
    ) private pure returns (address pair) {
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            initCodeHash
                        )
                    )
                )
            )
        );
    }

    /// Calculates the v2 address for a pair and fetches the reserves for each token
    function pairAndReservesFor(
        address factory,
        bytes32 initCodeHash,
        address tokenA,
        address tokenB
    ) private view returns (address pair, uint256 reserveA, uint256 reserveB) {
        address token0;
        (pair, token0) = pairAndToken0For(
            factory,
            initCodeHash,
            tokenA,
            tokenB
        );
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair)
            .getReserves();
        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    /// Given an input asset amount returns the maximum output amount of the other asset
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        if (reserveIn == 0 || reserveOut == 0) revert InvalidReserves();
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /// Returns the input amount needed for a desired output amount in a single-hop trade
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        if (reserveIn == 0 || reserveOut == 0) revert InvalidReserves();
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    /// Returns the input amount needed for a desired output amount in a multi-hop trade
    function getAmountInMultihop(
        address factory,
        bytes32 initCodeHash,
        uint256 amountOut,
        address[] memory path
    ) internal view returns (uint256 amount, address pair) {
        if (path.length < 2) revert InvalidPath();
        amount = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            uint256 reserveIn;
            uint256 reserveOut;

            (pair, reserveIn, reserveOut) = pairAndReservesFor(
                factory,
                initCodeHash,
                path[i - 1],
                path[i]
            );
            amount = getAmountIn(amount, reserveIn, reserveOut);
        }
    }

    /// Sorts two tokens to return token0 and token1
    function sortTokens(
        address tokenA,
        address tokenB
    ) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
    }
}
