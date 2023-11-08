// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOmniTxAdapter.sol";

interface IUniswapV3 is IOmniTxAdapter {
    error InvalidAction(uint8 action);
    error InvalidPath(bytes path);

    function router() external view returns (address);

    function weth() external view returns (address);
}
