// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOmniTxReceiver.sol";

interface IUniswapV2 is IOmniTxReceiver {
    error InvalidAction(uint8 action);
    error InvalidPath(address[] path);
    error NotNative(address token);

    function router() external view returns (address);
}
