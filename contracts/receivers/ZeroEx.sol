// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "../interfaces/IZeroEx.sol";
import "../libraries/RefundUtils.sol";

contract ZeroEx is IZeroEx {
    address public immutable omniTx;
    address public immutable proxy;

    constructor(address _omniTx, address _proxy) {
        omniTx = _omniTx;
        proxy = _proxy;
    }

    receive() external payable {}

    function otReceive(
        address srcFrom,
        address tokenIn,
        uint256 amountIn,
        bytes calldata data
    ) external payable returns (address tokenOut, uint256 amountOut) {
        if (msg.sender != omniTx) revert Forbidden();

        if (tokenIn != address(0)) {
            IERC20(tokenIn).approve(proxy, amountIn);
        }

        (bool ok, bytes memory reason) = proxy.call{value: tokenIn == address(0) ? amountIn : 0}(data[20:]);
        if (!ok) revert CallFailure(reason);

        if (tokenIn != address(0)) {
            IERC20(tokenIn).approve(proxy, 0);
        }

        tokenOut = address(bytes20(data[0:20]));
        if (tokenOut == address(0)) {
            amountOut = RefundUtils.refundNative(omniTx, address(0));
        } else {
            amountOut = RefundUtils.refundERC20(tokenOut, omniTx, address(0));
            RefundUtils.refundNative(omniTx, address(0));
        }
        if (amountOut == 0) revert InvalidTokenOut(tokenOut);

        emit OTReceive(srcFrom, tokenIn, amountIn, data);
    }
}
