// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IDisperse.sol";
import "../libraries/RefundUtils.sol";

contract Disperse is IDisperse {
    using SafeERC20 for IERC20;
    using Address for address payable;

    address public immutable omniTx;

    constructor(address _omniTx) {
        omniTx = _omniTx;
    }

    function otReceive(
        address srcFrom,
        address tokenIn,
        uint256 amountIn,
        bytes calldata data
    ) external payable returns (address, uint256) {
        if (msg.sender != omniTx) revert Forbidden();

        (address[] memory recipients, uint256[] memory amounts) = abi.decode(data, (address[], uint256[]));
        _disperse(tokenIn, recipients, amounts, srcFrom);

        emit OTReceive(srcFrom, tokenIn, amountIn, data);

        return (address(0), 0);
    }

    function _disperse(
        address tokenIn,
        address[] memory recipients,
        uint256[] memory amounts,
        address refundAddress
    ) internal {
        uint256 length = recipients.length;
        if (length != amounts.length) revert InvalidParams();

        if (tokenIn == address(0)) {
            for (uint256 i; i < length; ) {
                uint256 amount = amounts[i];
                if (amount > 0) {
                    payable(recipients[i]).sendValue(amount);
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
                }
                unchecked {
                    ++i;
                }
            }
        }

        RefundUtils.refundERC20(tokenIn, refundAddress, address(0));
        RefundUtils.refundNative(refundAddress, address(0));

        emit Disperse(tokenIn, recipients, amounts);
    }
}
