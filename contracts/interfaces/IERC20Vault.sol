// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20Receiver.sol";

interface IERC20Vault is IERC20Receiver {
    error Forbidden();
    error InvalidToken();
    error InsufficientBalance();

    event Withdraw(address indexed token, address indexed to, uint256 amount);

    function omniTx() external view returns (address);

    function balances(address token, address account) external view returns (uint256);

    function withdraw(
        address token,
        address to,
        uint256 amount
    ) external;
}
