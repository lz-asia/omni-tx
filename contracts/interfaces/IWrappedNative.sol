// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOmniTxReceiver.sol";

interface IWrappedNative is IOmniTxReceiver {
    error NotWhitelisted(address addr);
    error NotNative(address token);
    error InvalidAction(uint8 action);

    event UpdateWhitelisted(address addr, bool whitelisted);

    function whitelisted(address addr) external view returns (bool);

    function updateWhitelisted(address addr, bool _whitelisted) external;
}
