// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IDisperse.sol";
import "./interfaces/IOmniTx.sol";
import "./ERC20Vault.sol";

contract Disperse is ERC20Vault, IDisperse {
    using SafeERC20 for IERC20;
    using Address for address payable;

    constructor(address _omniTx) ERC20Vault(_omniTx) {}

    receive() external payable {}

    function otReceive(
        address srcFrom,
        address tokenIn,
        uint256 amountIn,
        bytes calldata data
    ) external payable returns (address, uint256) {
        if (msg.sender != omniTx) revert Forbidden();

        (address[] memory recipients, uint256[] memory amounts) = abi.decode(data, (address[], uint256[]));
        _disperse(tokenIn, amountIn, recipients, amounts, srcFrom);

        emit OTReceive(srcFrom, tokenIn, amountIn, data);

        return (address(0), 0);
    }

    function disperse(
        address token,
        uint256 amount,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        _disperse(token, amount, recipients, amounts, msg.sender);
    }

    function disperseIntrinsic(
        address token,
        uint256 amount,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external {
        if (amount > balances[token][msg.sender]) revert InsufficientBalance();
        balances[token][msg.sender] -= amount;

        _disperse(token, amount, recipients, amounts, msg.sender);
    }

    function _disperse(
        address tokenIn,
        uint256 amountIn,
        address[] memory recipients,
        uint256[] memory amounts,
        address refundAddress
    ) internal {
        uint256 length = recipients.length;
        if (length != amounts.length) revert InvalidParams();

        uint256 amountTotal;
        if (tokenIn == address(0)) {
            for (uint256 i; i < length; ) {
                uint256 amount = amounts[i];
                if (amount > 0) {
                    payable(recipients[i]).sendValue(amount);
                    amountTotal += amount;
                }
                unchecked {
                    ++i;
                }
            }
        } else {
            for (uint256 i; i < length; ) {
                uint256 amount = amounts[i];
                if (amount > 0) {
                    IERC20(tokenIn).safeTransfer(recipients[i], amount);
                    amountTotal += amount;
                }
                unchecked {
                    ++i;
                }
            }
        }

        if (amountTotal < amountIn) {
            IERC20(tokenIn).safeTransfer(refundAddress, amountIn - amountTotal);
        }

        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(refundAddress).sendValue(balance);
        }
    }
}
