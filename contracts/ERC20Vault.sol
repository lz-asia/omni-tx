// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IERC20Vault.sol";

contract ERC20Vault is IERC20Vault {
    using SafeERC20 for IERC20;

    address public immutable omniTx;
    mapping(address => mapping(address => uint256)) public balances;

    constructor(address _omniTx) {
        omniTx = _omniTx;
    }

    function onReceiveERC20(
        address token,
        address to,
        uint256 amount
    ) external {
        if (msg.sender != omniTx) revert Forbidden();
        if (token == address(0)) revert InvalidToken();

        balances[token][to] += amount;

        emit OnReceiveERC20(token, to, amount);
    }

    function withdraw(
        address token,
        address to,
        uint256 amount
    ) external {
        if (amount > balances[token][msg.sender]) revert InsufficientBalance();
        balances[token][msg.sender] -= amount;

        IERC20(token).safeTransfer(to, amount);

        emit Withdraw(token, to, amount);
    }
}
