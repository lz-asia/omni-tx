// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library RefundUtils {
    error RefundFailure();
    event RefundFallback(address indexed token, uint256 amount);

    function refundNative(address to, address _fallback) internal {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool ok, ) = to.call{value: balance}("");
            if (!ok) {
                if (_fallback == address(0)) revert RefundFailure();
                else {
                    emit RefundFallback(address(0), balance);
                    _fallback.call{value: balance}("");
                }
            }
        }
    }

    function refundERC20(
        address token,
        address to,
        address _fallback
    ) internal {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            if (!_safeTransfer(token, to, balance)) {
                if (_fallback == address(0)) revert RefundFailure();
                else {
                    emit RefundFallback(token, balance);
                    IERC20(token).transfer(_fallback, balance);
                }
            }
        }
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) private returns (bool) {
        (bool success, bytes memory data) = token.call(abi.encodeCall(IERC20.transfer, (to, amount)));
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }
}
