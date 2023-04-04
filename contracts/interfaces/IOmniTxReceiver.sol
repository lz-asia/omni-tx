// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20Receiver.sol";

interface IOmniTxReceiver is IERC20Receiver {
    event OTReceive(address indexed srcFrom, address indexed token, uint256 amount, bytes data);

    function otReceive(
        address srcFrom,
        address tokenIn,
        uint256 amountIn,
        bytes calldata data
    ) external payable returns (address tokenOut, uint256 amountOut);
}
