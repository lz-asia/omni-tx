// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOmniTxReceiver.sol";

interface IUniswapV3 is IOmniTxReceiver {
    error InvalidAction(uint8 action);
    error InvalidPath(bytes path);

    function router() external view returns (address);

    function swap(
        address token,
        uint256 amount,
        bytes calldata data
    ) external;
}
