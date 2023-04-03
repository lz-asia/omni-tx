// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IStargateReceiver.sol";
import "./interfaces/IOmniTx.sol";
import "./interfaces/IStargateRouter.sol";
import "./interfaces/IStargateFactory.sol";
import "./interfaces/IStargatePool.sol";
import "./interfaces/IOmniTxReceiver.sol";
import "./libraries/RefundUtils.sol";

contract OmniTx is Ownable, ReentrancyGuard, IStargateReceiver, IOmniTx {
    using SafeERC20 for IERC20;
    using Address for address payable;

    address public immutable router;
    address public immutable factory;
    address public wallet;
    mapping(uint16 => address) public dstAddress;

    constructor(address _router, address _wallet) {
        router = _router;
        factory = IStargateRouter(_router).factory();
        wallet = _wallet;
        emit UpdateWallet(_wallet);
    }

    function estimateFee(
        uint16 dstChainId,
        address[] calldata dstReceivers,
        bytes[] calldata dstData,
        uint256 dstGasForCall,
        uint256 dstNativeAmount,
        address from
    ) external view returns (uint256) {
        address dst = dstAddress[dstChainId];
        if (dst == address(0)) revert DstChainNotFound(dstChainId);

        (uint256 fee, ) = IStargateRouter(router).quoteLayerZeroFee(
            dstChainId,
            1, /*TYPE_SWAP_REMOTE*/
            abi.encodePacked(dst),
            abi.encode(from, dstReceivers, dstData),
            IStargateRouter.lzTxObj(dstGasForCall, dstNativeAmount, abi.encodePacked(from))
        );
        return fee;
    }

    function updateWallet(address _wallet) external onlyOwner {
        wallet = _wallet;
        emit UpdateWallet(_wallet);
    }

    function updateDstAddress(uint16 dstChainId, address _dstAddress) external onlyOwner {
        dstAddress[dstChainId] = _dstAddress;
        emit UpdateDstAddress(dstChainId, _dstAddress);
    }

    function transferNative(
        uint256 amount,
        address[] calldata receivers,
        bytes[] calldata data,
        TransferParams calldata params
    ) external payable {
        (address tokenOut, uint256 amountOut) = _callReceivers(address(0), amount, receivers, data, false, msg.sender);
        _transfer(tokenOut, amountOut, params, payable(msg.sender), msg.value - amount);
    }

    function transferERC20(
        address token,
        uint256 amount,
        address[] calldata receivers,
        bytes[] calldata data,
        TransferParams calldata params
    ) external payable {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        (address tokenOut, uint256 amountOut) = _callReceivers(token, amount, receivers, data, false, msg.sender);
        _transfer(tokenOut, amountOut, params, payable(msg.sender), msg.value);
    }

    function _transfer(
        address token,
        uint256 amount,
        TransferParams calldata params,
        address payable from,
        uint256 fee
    ) internal {
        address dst = dstAddress[params.dstChainId];
        if (dst == address(0)) revert DstChainNotFound(params.dstChainId);

        address pool = IStargateFactory(factory).getPool(params.poolId);
        if (pool == address(0)) revert PoolNotFound(params.poolId);

        address _token = IStargatePool(pool).token();
        if (token != _token) revert InvalidPoolId(params.poolId);

        IERC20(_token).approve(router, amount);
        IStargateRouter(router).swap{value: fee}(
            params.dstChainId,
            params.poolId,
            params.dstPoolId,
            from,
            amount,
            params.dstMinAmount,
            IStargateRouter.lzTxObj(params.dstGasForCall, params.dstNativeAmount, abi.encodePacked(from)),
            abi.encodePacked(dst),
            abi.encode(from, params.dstReceivers, params.dstData)
        );

        RefundUtils.refundERC20(_token, from, address(0));
        RefundUtils.refundNative(from, address(0));
    }

    //---------------------------------------------------------------------------
    // RECEIVER FUNCTIONS
    function estimateGas(
        address swapTo,
        bytes calldata swapData,
        uint16 srcChainId,
        bytes calldata srcAddress,
        uint256 nonce,
        address token,
        uint256 amountLD,
        bytes calldata payload
    ) external payable returns (uint256 gasSpent) {
        (bool ok, bytes memory reason) = swapTo.call{value: msg.value}(swapData);
        if (!ok) revert SwapFailure(reason);

        uint256 gas = gasleft();
        _sgReceive(srcChainId, srcAddress, nonce, token, amountLD, payload);
        return gas - gasleft();
    }

    function sgReceive(
        uint16 srcChainId,
        bytes calldata srcAddress,
        uint256 nonce,
        address token,
        uint256 amountLD,
        bytes calldata payload
    ) external nonReentrant {
        if (msg.sender != router) revert Forbidden();

        _sgReceive(srcChainId, srcAddress, nonce, token, amountLD, payload);
    }

    function _sgReceive(
        uint16 srcChainId,
        bytes calldata srcAddress,
        uint256 nonce,
        address token,
        uint256 amountLD,
        bytes calldata payload
    ) internal {
        (address srcFrom, address[] memory receivers, bytes[] memory data) = abi.decode(
            payload,
            (address, address[], bytes[])
        );
        (address tokenOut, ) = _callReceivers(token, amountLD, receivers, data, true, srcFrom);
        if (tokenOut != address(0)) {
            RefundUtils.refundERC20(tokenOut, srcFrom, wallet);
        }
        RefundUtils.refundNative(srcFrom, wallet);

        emit SGReceive(srcChainId, srcAddress, nonce, srcFrom, token, amountLD);
    }

    function _callReceivers(
        address tokenIn,
        uint256 amountIn,
        address[] memory receivers,
        bytes[] memory data,
        bool _fallback,
        address from
    ) internal returns (address _tokenOut, uint256 _amountOut) {
        if (receivers.length != data.length) revert InvalidParamLengths();

        for (uint256 i; i < receivers.length; ) {
            address to = receivers[i];
            if (tokenIn != address(0)) {
                IERC20(tokenIn).safeTransfer(to, amountIn);
            }
            bool native = tokenIn == address(0);
            try IOmniTxReceiver(to).otReceive{value: native ? amountIn : 0}(from, tokenIn, amountIn, data[i]) returns (
                address tokenOut,
                uint256 amountOut
            ) {
                if (!native) {
                    RefundUtils.refundERC20(tokenIn, from, _fallback ? wallet : address(0));
                }
                emit CallSuccess(from, to, tokenIn, amountIn);
                (tokenIn, amountIn) = (tokenOut, amountOut);
            } catch (bytes memory reason) {
                if (!native) {
                    try IOmniTxReceiver(to).onReceiveERC20(tokenIn, from, amountIn) {} catch {}
                }
                emit CallFailure(from, to, tokenIn, amountIn, data[i], reason);
                return (address(0), 0);
            }
            unchecked {
                ++i;
            }
        }

        return (tokenIn, amountIn);
    }
}
