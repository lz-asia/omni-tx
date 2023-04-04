// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOmniTxReceiver.sol";

interface IDisperse is IOmniTxReceiver {
    error InvalidParams();

    event Disperse(address indexed token, address[] recipients, uint256[] amounts);

    struct DisperseParams {
        address token;
        address[] recipients;
        uint256[] amounts;
        address refundAddress;
    }

    receive() external payable;

    function disperse(
        address token,
        uint256 amount,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external;

    function disperseIntrinsic(
        address token,
        uint256 amount,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external;
}
