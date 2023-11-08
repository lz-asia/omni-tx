// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOmniTxAdapter.sol";

interface IZeroEx is IOmniTxAdapter {
    error CallFailure(bytes reason);
    error InvalidTokenOut(address tokenOut);

    function proxy() external view returns (address);
}
