// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "../interfaces/IWrappedNative.sol";
import "../libraries/RefundUtils.sol";

contract WrappedNative is Ownable, IWrappedNative {
    using SafeERC20 for IERC20;
    using Address for address payable;

    uint8 private constant WRAP = 1;
    uint8 private constant UNWRAP = 2;

    address public immutable omniTx;
    mapping(address => bool) public whitelisted;

    constructor(address _omniTx) {
        omniTx = _omniTx;
    }

    receive() external payable {}

    function updateWhitelisted(address addr, bool _whitelisted) external onlyOwner {
        whitelisted[addr] = _whitelisted;
        emit UpdateWhitelisted(addr, _whitelisted);
    }

    function otReceive(
        address srcFrom,
        address tokenIn,
        uint256 amountIn,
        bytes calldata data
    ) external payable returns (address tokenOut, uint256 amountOut) {
        if (msg.sender != omniTx) revert Forbidden();

        uint8 action = uint8(bytes1(data[0:1]));
        if (action == WRAP) {
            (tokenOut, amountOut) = _wrap(tokenIn, amountIn, data);
        } else if (action == UNWRAP) {
            (tokenOut, amountOut) = _unwrap(tokenIn, amountIn);
        } else revert InvalidAction(action);

        RefundUtils.refundERC20(tokenIn, srcFrom, address(0));
        RefundUtils.refundNative(srcFrom, address(0));

        emit OTReceive(srcFrom, tokenIn, amountIn, data);
    }

    function _wrap(address tokenIn, uint256 amountIn, bytes calldata data) internal returns (address, uint256) {
        if (tokenIn != address(0)) revert NotNative(tokenIn);

        address weth = address(bytes20(data[1:21]));
        if (!whitelisted[weth]) revert NotWhitelisted(weth);

        IWETH(weth).deposit{value: amountIn}();
        IERC20(weth).safeTransfer(omniTx, amountIn);

        return (weth, amountIn);
    }

    function _unwrap(address tokenIn, uint256 amountIn) internal returns (address, uint256) {
        if (!whitelisted[tokenIn]) revert NotWhitelisted(tokenIn);

        IWETH(tokenIn).withdraw(amountIn);
        payable(omniTx).sendValue(amountIn);

        return (address(0), amountIn);
    }
}
