// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOmniTxAdapter.sol";

interface IAaveV3 is IOmniTxAdapter {
    error InvalidAction(uint8 action);
}
