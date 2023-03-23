// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IDisperse.sol";
import "./libraries/SwapUtils.sol";

contract Disperse is Ownable, IDisperse {
    using SafeERC20 for IERC20;
    using Address for address payable;

    address public immutable sgProxy;
    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => bool) public isCallable;

    constructor(address _sgProxy) {
        sgProxy = _sgProxy;
    }

    receive() external payable {}

    function updateCallable(address addr, bool callable) external onlyOwner {
        isCallable[addr] = callable;

        emit UpdateCallable(addr, callable);
    }

    function onReceiveERC20(
        address token,
        address to,
        uint256 amount
    ) external {
        if (msg.sender != sgProxy) revert InvalidProxy();
        if (token == address(0)) revert InvalidToken();

        balances[token][to] += amount;

        emit OnReceiveERC20(token, to, amount);
    }

    function sgProxyReceive(
        address srcFrom,
        address token,
        uint256 amount,
        bytes calldata data
    ) external {
        if (msg.sender != sgProxy) revert InvalidProxy();

        (
            address tokenOut,
            address swapTo,
            bytes memory swapData,
            address[] memory recipients,
            uint256[] memory amounts,
            address refundAddress
        ) = abi.decode(data, (address, address, bytes, address[], uint256[], address));

        _disperse(amount, token, tokenOut, swapTo, swapData, recipients, amounts, refundAddress);

        emit SgProxyReceive(srcFrom, token, amount, data);
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

    function disperse(DisperseParams calldata params) external {
        IERC20(params.tokenIn).safeTransferFrom(msg.sender, address(this), params.amountIn);

        _disperse(
            params.amountIn,
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
        if (params.amountIn > balances[params.tokenIn][msg.sender]) revert InsufficientBalance();
        balances[params.tokenIn][msg.sender] -= params.amountIn;

        _disperse(
            params.amountIn,
            params.tokenIn,
            params.tokenOut,
            params.swapTo,
            params.swapData,
            params.recipients,
            params.amounts,
            params.refundAddress
        );
    }

    function _disperse(
        uint256 amountIn,
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

        if (swapData.length > 0) {
            if (!isCallable[swapTo]) revert InvalidSwapData();
            SwapUtils.swapERC20(tokenIn, amountIn, swapTo, swapData, tokenIn != tokenOut, refundAddress);
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
            uint256 balanceTokenOut = IERC20(tokenOut).balanceOf(address(this));
            if (balanceTokenOut > 0) {
                IERC20(tokenOut).safeTransfer(refundAddress, balanceTokenOut);
            }
        }

        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(refundAddress).sendValue(balance);
        }
    }
}
