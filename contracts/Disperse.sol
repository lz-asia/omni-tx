// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IDisperse.sol";

contract Disperse is IDisperse {
    using SafeERC20 for IERC20;
    using Address for address payable;

    receive() external payable {}

    function disperse(
        address token,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external payable {
        _disperse(token, recipients, amounts);
    }

    function swapAndDisperse(
        bytes[] calldata swapDataWithValue,
        address token,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external payable {
        uint256 length = swapDataWithValue.length;
        for (uint256 i; i < length; ) {
            (address to, bytes memory data, uint256 value) = abi.decode(
                swapDataWithValue[i],
                (address, bytes, uint256)
            );
            Address.functionCallWithValue(to, data, value);
            unchecked {
                ++i;
            }
        }
        _disperse(token, recipients, amounts);
    }

    function _disperse(
        address token,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) internal {
        uint256 length = recipients.length;
        if (length != amounts.length) revert LengthsAreNotEqual();

        if (token == address(0)) {
            for (uint256 i; i < length; ) {
                uint256 amount = amounts[i];
                if (amount != 0) payable(recipients[i]).sendValue(amount);
                unchecked {
                    ++i;
                }
            }
            uint256 amountRemained = address(this).balance;
            if (amountRemained != 0) payable(msg.sender).sendValue(amountRemained);
        } else {
            for (uint256 i; i < length; ) {
                uint256 amount = amounts[i];
                if (amount != 0) IERC20(token).safeTransfer(recipients[i], amount);
                unchecked {
                    ++i;
                }
            }
            uint256 amountRemained = IERC20(token).balanceOf(address(this));
            if (amountRemained != 0) IERC20(token).safeTransfer(msg.sender, amountRemained);
        }
    }
}
