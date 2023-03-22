// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IStargateVault {
    error InvalidProxy();

    function sgProxy() external view returns (address);

    function onReceiveERC20(
        address token,
        address to,
        uint256 amount
    ) external;
}
