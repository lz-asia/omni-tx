// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IStargateVault {
    function onReceiveERC20(
        address token,
        address to,
        uint256 amount
    ) external;
}
