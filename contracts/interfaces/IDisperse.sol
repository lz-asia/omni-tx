// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IDisperse {
    error LengthsAreNotEqual();

    function disperse(
        address token,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external payable;

    function swapAndDisperse(
        bytes[] calldata swapDataWithValue,
        address token,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external payable;
}
