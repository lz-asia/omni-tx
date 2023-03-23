// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library SwapUtils {
    using SafeERC20 for IERC20;
    using Address for address payable;

    error SwapFailure(bytes reason);

    function swapNative(
        uint256 amount,
        address to,
        bytes memory data,
        bool sweep,
        address refundAddress
    ) internal {
        (bool ok, bytes memory reason) = to.call{value: amount}(data);
        if (!ok) revert SwapFailure(reason);

        if (sweep) {
            uint256 balance = address(this).balance;
            if (balance > 0) {
                payable(refundAddress).sendValue(balance);
            }
        }
    }

    function swapERC20(
        address token,
        uint256 amount,
        address to,
        bytes memory data,
        bool sweep,
        address refundAddress
    ) internal {
        IERC20(token).approve(to, amount);
        (bool ok, bytes memory reason) = to.call(data);
        if (!ok) revert SwapFailure(reason);
        IERC20(token).approve(to, 0);

        if (sweep) {
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) {
                IERC20(token).safeTransfer(refundAddress, balance);
            }
        }
    }
}
