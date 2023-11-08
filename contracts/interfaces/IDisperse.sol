// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOmniTxAdapter.sol";

interface IDisperse is IOmniTxAdapter {
    error InvalidParams();

    event Disperse(address indexed token, address[] recipients, uint256[] amounts);
}
