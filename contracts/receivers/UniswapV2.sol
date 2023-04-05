// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "../interfaces/IUniswapV2.sol";
import "../libraries/RefundUtils.sol";

contract UniswapV2 is IUniswapV2 {
    using SafeERC20 for IERC20;

    uint8 private constant SWAP_EXACT_TOKENS_FOR_TOKENS = 1;
    uint8 private constant SWAP_TOKENS_FOR_EXACT_TOKENS = 2;
    uint8 private constant SWAP_EXACT_ETH_FOR_TOKENS = 3;
    uint8 private constant SWAP_TOKENS_FOR_EXACT_ETH = 4;

    address public immutable omniTx;
    address public immutable router;

    constructor(address _omniTx, address _router) {
        omniTx = _omniTx;
        router = _router;
    }

    function otReceive(
        address srcFrom,
        address tokenIn,
        uint256 amountIn,
        bytes calldata data
    ) external payable returns (address tokenOut, uint256 amountOut) {
        if (msg.sender != omniTx) revert Forbidden();

        (tokenOut, amountOut) = _swap(tokenIn, amountIn, data, srcFrom);

        emit OTReceive(srcFrom, tokenIn, amountIn, data);
    }

    function _swap(
        address tokenIn,
        uint256 amountIn,
        bytes calldata data,
        address refundAddress
    ) internal returns (address tokenOut, uint256 amountOut) {
        if (tokenIn != address(0)) {
            IERC20(tokenIn).approve(router, amountIn);
        }

        uint8 action = uint8(bytes1(data[0:1]));
        if (action == SWAP_EXACT_TOKENS_FOR_TOKENS) {
            (tokenOut, amountOut) = _swapExactTokensForTokens(tokenIn, amountIn, data[1:]);
        } else if (action == SWAP_TOKENS_FOR_EXACT_TOKENS) {
            (tokenOut, amountOut) = _swapTokensForExactTokens(tokenIn, amountIn, data[1:]);
        } else if (action == SWAP_EXACT_ETH_FOR_TOKENS) {
            (tokenOut, amountOut) = _swapExactETHForTokens(tokenIn, amountIn, data[1:]);
        } else if (action == SWAP_TOKENS_FOR_EXACT_ETH) {
            (tokenOut, amountOut) = _swapTokensForExactETH(tokenIn, amountIn, data[1:]);
        } else revert InvalidAction(action);

        if (tokenIn != address(0)) {
            IERC20(tokenIn).approve(router, 0);
        }

        RefundUtils.refundERC20(tokenIn, refundAddress, address(0));
        RefundUtils.refundNative(refundAddress, address(0));
    }

    function _swapExactTokensForTokens(
        address tokenIn,
        uint256 amountIn,
        bytes memory args
    ) internal returns (address, uint256) {
        (uint256 amountOutMin, address[] memory path, uint256 deadline) = abi.decode(
            args,
            (uint256, address[], uint256)
        );
        if (path[0] != tokenIn) revert InvalidPath(path);

        uint256[] memory amounts = IUniswapV2Router01(router).swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            omniTx,
            deadline
        );
        return (path[path.length - 1], amounts[amounts.length - 1]);
    }

    function _swapTokensForExactTokens(
        address tokenIn,
        uint256 amountIn,
        bytes memory args
    ) internal returns (address, uint256) {
        (uint256 amountOut, address[] memory path, uint256 deadline) = abi.decode(args, (uint256, address[], uint256));
        if (path[0] != tokenIn) revert InvalidPath(path);

        IUniswapV2Router01(router).swapTokensForExactTokens(amountOut, amountIn, path, omniTx, deadline);
        return (path[path.length - 1], amountOut);
    }

    function _swapExactETHForTokens(
        address tokenIn,
        uint256 amountIn,
        bytes memory args
    ) internal returns (address, uint256) {
        (uint256 amountOutMin, address[] memory path, uint256 deadline) = abi.decode(
            args,
            (uint256, address[], uint256)
        );
        if (tokenIn != address(0)) revert NotNative(tokenIn);

        uint256[] memory amounts = IUniswapV2Router01(router).swapExactETHForTokens{value: amountIn}(
            amountOutMin,
            path,
            omniTx,
            deadline
        );
        return (path[path.length - 1], amounts[amounts.length - 1]);
    }

    function _swapTokensForExactETH(
        address tokenIn,
        uint256 amountIn,
        bytes memory args
    ) internal returns (address, uint256) {
        (, uint256 amountOut) = _swapTokensForExactTokens(tokenIn, amountIn, args);
        return (address(0), amountOut);
    }
}
