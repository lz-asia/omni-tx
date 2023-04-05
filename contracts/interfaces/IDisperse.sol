// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOmniTxReceiver.sol";

interface IDisperse is IOmniTxReceiver {
    error InvalidParams();

    event Disperse(address indexed token, address[] recipients, uint256[] amounts);
}
