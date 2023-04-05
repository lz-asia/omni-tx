// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOmniTxReceiver.sol";

interface IAaveV3 is IOmniTxReceiver {
    error InvalidAction(uint8 action);
}
