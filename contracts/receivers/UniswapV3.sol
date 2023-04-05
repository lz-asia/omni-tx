// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";
import "../interfaces/IUniswapV3.sol";
import "../libraries/RefundUtils.sol";
import "../ERC20Vault.sol";

contract UniswapV3 is IUniswapV3 {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    uint8 private constant SWAP_EXACT_INPUT_SINGLE = 1;
    uint8 private constant SWAP_EXACT_INPUT = 2;
    uint8 private constant SWAP_EXACT_OUTPUT_SINGLE = 3;
    uint8 private constant SWAP_EXACT_OUTPUT = 4;

    address public immutable omniTx;
    address public immutable router;
    address public immutable weth;

    constructor(
        address _omniTx,
        address _router,
        address _weth
    ) {
        omniTx = _omniTx;
        router = _router;
        weth = _weth;
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
        if (tokenIn == address(0)) {
            IWETH(weth).deposit{value: amountIn}();
            tokenIn = weth;
        }
        IERC20(tokenIn).approve(router, amountIn);

        uint8 action = uint8(bytes1(data[0:1]));
        if (action == SWAP_EXACT_INPUT_SINGLE) {
            (tokenOut, amountOut) = _swapExactInputSingle(tokenIn, amountIn, data[1:]);
        } else if (action == SWAP_EXACT_INPUT) {
            (tokenOut, amountOut) = _swapExactInput(tokenIn, amountIn, data[1:]);
        } else if (action == SWAP_EXACT_OUTPUT_SINGLE) {
            (tokenOut, amountOut) = _swapExactOutputSingle(tokenIn, amountIn, data[1:]);
        } else if (action == SWAP_EXACT_OUTPUT) {
            (tokenOut, amountOut) = _swapExactOutput(tokenIn, amountIn, data[1:]);
        } else revert InvalidAction(action);

        IERC20(tokenIn).approve(router, 0);

        RefundUtils.refundERC20(tokenIn, refundAddress, address(0));
        RefundUtils.refundNative(refundAddress, address(0));
    }

    function _swapExactInputSingle(
        address tokenIn,
        uint256 amountIn,
        bytes memory args
    ) internal returns (address, uint256) {
        (address tokenOut, uint24 fee, uint256 deadline, uint256 amountOutMinimum, uint160 sqrtPriceLimitX96) = abi
            .decode(args, (address, uint24, uint256, uint256, uint160));

        uint256 amountOut = ISwapRouter(router).exactInputSingle(
            ISwapRouter.ExactInputSingleParams(
                tokenIn,
                tokenOut,
                fee,
                omniTx,
                deadline,
                amountIn,
                amountOutMinimum,
                sqrtPriceLimitX96
            )
        );
        return (tokenOut, amountOut);
    }

    function _swapExactInput(
        address tokenIn,
        uint256 amountIn,
        bytes memory args
    ) internal returns (address, uint256) {
        (bytes memory path, uint256 deadline, uint256 amountOutMinimum) = abi.decode(args, (bytes, uint256, uint256));
        if (path.toAddress(0) != tokenIn) revert InvalidPath(path);

        uint256 amountOut = ISwapRouter(router).exactInput(
            ISwapRouter.ExactInputParams(path, omniTx, deadline, amountIn, amountOutMinimum)
        );
        return (path.toAddress(path.length - 20), amountOut);
    }

    function _swapExactOutputSingle(
        address tokenIn,
        uint256 amountIn,
        bytes memory args
    ) internal returns (address, uint256) {
        (address tokenOut, uint24 fee, uint256 deadline, uint256 amountOut, uint160 sqrtPriceLimitX96) = abi.decode(
            args,
            (address, uint24, uint256, uint256, uint160)
        );

        ISwapRouter(router).exactOutputSingle(
            ISwapRouter.ExactOutputSingleParams(
                tokenIn,
                tokenOut,
                fee,
                omniTx,
                deadline,
                amountOut,
                amountIn,
                sqrtPriceLimitX96
            )
        );
        return (tokenOut, amountOut);
    }

    function _swapExactOutput(
        address tokenIn,
        uint256 amountIn,
        bytes memory args
    ) internal returns (address, uint256) {
        (bytes memory path, uint256 deadline, uint256 amountOut) = abi.decode(args, (bytes, uint256, uint256));
        if (path.toAddress(0) != tokenIn) revert InvalidPath(path);

        ISwapRouter(router).exactOutput(ISwapRouter.ExactOutputParams(path, omniTx, deadline, amountOut, amountIn));
        return (path.toAddress(path.length - 20), amountOut);
    }
}
