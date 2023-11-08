// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IERC20Receiver.sol";

library RefundUtils {
    error RefundFailure();
    event RefundFallbackSuccess(address indexed token, uint256 amount);
    event RefundFallbackFailure(address indexed token, uint256 amount);

    function refundNative(address to, address _fallback) internal returns (uint256 amount) {
        amount = address(this).balance;
        if (amount > 0) {
            (bool ok, ) = to.call{value: amount}("");
            if (!ok) {
                if (_fallback == address(0)) revert RefundFailure();

                (ok, ) = _fallback.call{value: amount}("");
                if (ok) {
                    emit RefundFallbackSuccess(address(0), amount);
                } else {
                    emit RefundFallbackFailure(address(0), amount);
                }
            }
        }
    }

    function refundERC20(address token, address to, address _fallback) internal returns (uint256 amount) {
        amount = IERC20(token).balanceOf(address(this));
        if (amount > 0) {
            if (!_safeTransfer(token, to, amount)) {
                if (_fallback == address(0)) revert RefundFailure();

                if (_safeTransfer(token, _fallback, amount)) {
                    try IERC20Receiver(_fallback).onReceiveERC20(token, to, amount) {} catch {}
                    emit RefundFallbackSuccess(token, amount);
                } else {
                    emit RefundFallbackFailure(token, amount);
                }
            }
        }
    }

    function _safeTransfer(address token, address to, uint256 amount) private returns (bool) {
        (bool success, bytes memory data) = token.call(abi.encodeCall(IERC20.transfer, (to, amount)));
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }
}
