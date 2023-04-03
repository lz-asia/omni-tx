// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOmniTxReceiver.sol";

interface IDisperse is IOmniTxReceiver {
    error InsufficientBalance();
    error InvalidParams();

    event Disperse(address indexed token, address[] recipients, uint256[] amounts);
    event Withdraw(address indexed token, address indexed to, uint256 amount);

    struct DisperseParams {
        address token;
        address[] recipients;
        uint256[] amounts;
        address refundAddress;
    }

    function omniTx() external view returns (address);

    function balances(address token, address account) external view returns (uint256);

    receive() external payable;

    function withdraw(
        address token,
        address to,
        uint256 amount
    ) external;

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
