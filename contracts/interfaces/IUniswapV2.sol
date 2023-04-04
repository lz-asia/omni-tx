// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOmniTxReceiver.sol";

interface IUniswapV2 is IOmniTxReceiver {
    error InvalidAction(uint8 action);
    error InvalidPath(address[] path);
    error NotNative(address token);
    error Expired(uint256 deadline);

    function router() external view returns (address);

    function swap(
        address token,
        uint256 amount,
        bytes calldata data
    ) external;
}
