// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOmniTxAdapter.sol";

interface IUniswapV2 is IOmniTxAdapter {
    error InvalidAction(uint8 action);
    error InvalidPath(address[] path);
    error NotNative(address token);

    function router() external view returns (address);
}
