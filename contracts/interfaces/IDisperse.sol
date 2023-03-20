// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IStargateVault.sol";

interface IDisperse is IStargateVault {
    error InvalidToken();
    error InsufficientBalance();
    error InvalidParams();
    error Exploited();

    struct DisperseParams {
        address tokenIn;
        address tokenOut;
        address swapTo;
        bytes swapData;
        address[] recipients;
        uint256[] amounts;
        address refundAddress;
    }

    function withdraw(
        address token,
        address to,
        uint256 amount
    ) external;

    function disperse(DisperseParams calldata params) external;

    function disperseIntrinsic(DisperseParams calldata params) external;
}
