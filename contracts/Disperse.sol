// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IDisperse.sol";

contract Disperse is IDisperse {
    using SafeERC20 for IERC20;
    using Address for address payable;

    address public immutable sgProxy;
    mapping(address => mapping(address => uint256)) public balances;

    constructor(address _sgProxy) {
        sgProxy = _sgProxy;
    }

    receive() external payable {}

    function onReceiveERC20(
        address token,
        address to,
        uint256 amount
    ) external {
        if (msg.sender != sgProxy) revert InvalidProxy();
        if (token == address(0)) revert InvalidToken();

        balances[token][to] += amount;
    }

    function sgProxyReceive(bytes calldata data) external {
        if (msg.sender != sgProxy) revert InvalidProxy();

        DisperseParams memory params = abi.decode(data, (DisperseParams));
        _disperse(
            params.tokenIn,
            params.tokenOut,
            params.swapTo,
            params.swapData,
            params.recipients,
            params.amounts,
            params.refundAddress
        );
    }

    function _sum(uint256[] calldata amounts) internal pure returns (uint256 amount) {
        for (uint256 i; i < amounts.length; ) {
            amount += amounts[i];
            unchecked {
                ++i;
            }
        }
    }

    function withdraw(
        address token,
        address to,
        uint256 amount
    ) external {
        if (amount > balances[token][msg.sender]) revert InsufficientBalance();
        balances[token][msg.sender] -= amount;

        IERC20(token).safeTransfer(to, amount);
    }

    function disperse(DisperseParams calldata params) external {
        uint256 amount = _sum(params.amounts);
        IERC20(params.tokenIn).safeTransferFrom(msg.sender, address(this), amount);

        _disperse(
            params.tokenIn,
            params.tokenOut,
            params.swapTo,
            params.swapData,
            params.recipients,
            params.amounts,
            params.refundAddress
        );
    }

    function disperseIntrinsic(DisperseParams calldata params) external {
        uint256 amount = _sum(params.amounts);
        if (amount > balances[params.tokenIn][msg.sender]) revert InsufficientBalance();
        balances[params.tokenIn][msg.sender] -= amount;

        uint256 balance = IERC20(params.tokenIn).balanceOf(address(this));
        _disperse(
            params.tokenIn,
            params.tokenOut,
            params.swapTo,
            params.swapData,
            params.recipients,
            params.amounts,
            params.refundAddress
        );
        if (balance - IERC20(params.tokenIn).balanceOf(address(this)) > amount) revert Exploited();
    }

    function _disperse(
        address tokenIn,
        address tokenOut,
        address swapTo,
        bytes memory swapData,
        address[] memory recipients,
        uint256[] memory amounts,
        address refundAddress
    ) internal {
        uint256 length = recipients.length;
        if (length != amounts.length) revert InvalidParams();

        uint256 balanceTokenOut;
        if (tokenOut != address(0)) {
            balanceTokenOut = IERC20(tokenOut).balanceOf(address(this));
        }
        if (swapData.length > 0) {
            if (IERC20(tokenIn).allowance(address(this), swapTo) == 0) {
                IERC20(tokenIn).approve(swapTo, type(uint256).max);
            }
            swapTo.call(swapData);
        }

        if (tokenOut == address(0)) {
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
                    IERC20(tokenOut).safeTransfer(recipients[i], amount);
                }
                unchecked {
                    ++i;
                }
            }
            uint256 balance = IERC20(tokenOut).balanceOf(address(this));
            if (balance > balanceTokenOut) {
                IERC20(tokenOut).safeTransfer(refundAddress, balance - balanceTokenOut);
            }
        }

        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(refundAddress).sendValue(balance);
        }
    }
}
