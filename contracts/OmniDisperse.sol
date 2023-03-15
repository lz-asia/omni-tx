// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IStargateReceiver.sol";
import "./interfaces/IStargateRouter.sol";
import "./interfaces/IStargateFactory.sol";
import "./interfaces/IStargatePool.sol";
import "./interfaces/IOmniDisperse.sol";
import "./libraries/ExcessivelySafeCall.sol";

contract OmniDisperse is Ownable, IStargateReceiver, IOmniDisperse {
    using SafeERC20 for IERC20;
    using ExcessivelySafeCall for address;

    uint8 public constant TYPE_TRANSFER_ERC20 = 0;
    uint8 public constant TYPE_SWAP_TO_NATIVE = 1;

    address public immutable router;
    address public immutable factory;
    mapping(uint16 => address) public dstAddress;
    mapping(uint16 => mapping(address => mapping(address => mapping(uint256 => FailedMessage)))) public failedMessages; // srcChainId -> srcAddress -> srcFrom -> nonce -> FailedMessage

    constructor(address _router) {
        router = _router;
        factory = IStargateRouter(_router).factory();
    }

    function estimateFeeTransferERC20(
        uint16 dstChainId,
        address[] memory dstRecipients,
        uint256[] memory dstAmounts,
        uint256 gas,
        address from
    ) external view override returns (uint256) {
        address dst = dstAddress[dstChainId];
        if (dst == address(0)) revert DstChainNotFound(dstChainId);

        (uint256 fee, ) = IStargateRouter(router).quoteLayerZeroFee(
            dstChainId,
            1, /*TYPE_SWAP_REMOTE*/
            abi.encodePacked(dst),
            abi.encodePacked(TYPE_TRANSFER_ERC20, from, abi.encode(dstRecipients, dstAmounts)),
            IStargateRouter.lzTxObj(gas, 0, "0x")
        );
        return fee;
    }

    function estimateFeeSwapToNative(
        uint16 dstChainId,
        bytes[] memory swapData,
        address[] memory dstRecipients,
        uint256[] memory dstAmounts,
        uint256 gas,
        address from
    ) external view override returns (uint256) {
        address dst = dstAddress[dstChainId];
        if (dst == address(0)) revert DstChainNotFound(dstChainId);

        (uint256 fee, ) = IStargateRouter(router).quoteLayerZeroFee(
            dstChainId,
            1, /*TYPE_SWAP_REMOTE*/
            abi.encodePacked(dst),
            abi.encodePacked(TYPE_SWAP_TO_NATIVE, from, abi.encode(swapData, dstRecipients, dstAmounts)),
            IStargateRouter.lzTxObj(gas, 0, "0x")
        );
        return fee;
    }

    function updateDstAddress(uint16 dstChainId, address _dstAddress) external override onlyOwner {
        dstAddress[dstChainId] = _dstAddress;
        emit UpdateDstAddress(dstChainId, _dstAddress);
    }

    function transferERC20(TransferERC20Params memory params) external payable override {
        _transferERC20(params, payable(msg.sender), msg.value);
    }

    function _transferERC20(
        TransferERC20Params memory params,
        address payable from,
        uint256 fee
    ) internal {
        address dst = dstAddress[params.dstChainId];
        if (dst == address(0)) revert DstChainNotFound(params.dstChainId);

        address pool = IStargateFactory(factory).getPool(params.poolId);
        if (pool == address(0)) revert PoolNotFound(params.poolId);

        address token = IStargatePool(pool).token();
        IERC20(token).safeTransferFrom(from, address(this), params.amount);
        IERC20(token).approve(router, params.amount);
        IStargateRouter(router).swap{value: fee}(
            params.dstChainId,
            params.poolId,
            params.dstPoolId,
            from,
            params.amount,
            params.dstMinAmount,
            IStargateRouter.lzTxObj(params.gas, 0, "0x"),
            abi.encodePacked(dst),
            abi.encodePacked(TYPE_TRANSFER_ERC20, from, abi.encode(params.dstRecipients, params.dstAmounts))
        );
    }

    function transferERC20AndSwapToNative(TransferERC20AndSwapToNativeParams memory params) external payable override {
        _transferERC20AndSwapToNative(params, payable(msg.sender), msg.value);
    }

    function _transferERC20AndSwapToNative(
        TransferERC20AndSwapToNativeParams memory params,
        address payable from,
        uint256 fee
    ) internal {
        address dst = dstAddress[params.dstChainId];
        if (dst == address(0)) revert DstChainNotFound(params.dstChainId);

        address pool = IStargateFactory(factory).getPool(params.poolId);
        if (pool == address(0)) revert PoolNotFound(params.poolId);

        address token = IStargatePool(pool).token();
        IERC20(token).safeTransferFrom(from, address(this), params.amount);
        IERC20(token).approve(router, params.amount);
        IStargateRouter(router).swap{value: fee}(
            params.dstChainId,
            params.poolId,
            params.dstPoolId,
            from,
            params.amount,
            params.dstMinAmount,
            IStargateRouter.lzTxObj(params.gas, 0, "0x"),
            abi.encodePacked(dst),
            abi.encodePacked(
                TYPE_SWAP_TO_NATIVE,
                from,
                abi.encode(params.swapData, params.dstRecipients, params.dstAmounts)
            )
        );
    }

    //---------------------------------------------------------------------------
    // RECEIVER FUNCTIONS
    function sgReceive(
        uint16 srcChainId,
        bytes calldata srcAddress,
        uint256 nonce,
        address token,
        uint256 amountLD,
        bytes calldata payload
    ) external override {
        if (msg.sender != router) revert Forbidden();

        address _srcAddress = address(bytes20(srcAddress[0:20]));
        uint8 messageType = uint8(bytes1(payload[0:1]));
        address srcFrom = address(bytes20(payload[1:21]));
        bytes memory params = payload[21:];
        (bool success, bytes memory reason) = address(this).excessivelySafeCall(
            gasleft(),
            150,
            abi.encodeWithSelector(
                this.handleMessage.selector,
                messageType,
                srcChainId,
                _srcAddress,
                srcFrom,
                token,
                amountLD,
                params
            )
        );

        // try-catch all errors/exceptions
        if (!success) {
            failedMessages[srcChainId][_srcAddress][srcFrom][nonce] = FailedMessage(token, amountLD, keccak256(params));
            emit MessageFailed(srcChainId, _srcAddress, srcFrom, nonce, token, amountLD, params, reason);
        }

        emit SGReceive(srcChainId, srcAddress, nonce, token, amountLD, payload);
    }

    function handleMessage(
        uint8 messageType,
        uint16 srcChainId,
        address srcAddress,
        address srcFrom,
        address token,
        uint256 amountLD,
        bytes memory params
    ) public {
        if (msg.sender != address(this)) revert Forbidden();

        _handleMessage(messageType, srcChainId, srcAddress, srcFrom, token, amountLD, params);
    }

    function _handleMessage(
        uint8 messageType,
        uint16 srcChainId,
        address srcAddress,
        address srcFrom,
        address token,
        uint256 amountLD,
        bytes memory params
    ) internal {
        if (messageType == TYPE_SWAP_TO_NATIVE) {
            (bytes[] memory swapData, address[] memory recipients, uint256[] memory amounts) = abi.decode(
                params,
                (bytes[], address[], uint256[])
            );

            for (uint256 i; i < swapData.length; ) {
                (address to, bytes memory data) = abi.decode(swapData[i], (address, bytes));
                (bool ok, bytes memory reason) = to.call(data);
                if (!ok) revert SwapFailure(reason);

                unchecked {
                    ++i;
                }
            }

            uint256 amountTotal;
            for (uint256 i; i < recipients.length; ) {
                uint256 amount = amounts[i];
                (bool sent, bytes memory reason) = recipients[i].call{value: amount}("");
                if (sent) {
                    amountTotal += amount;
                } else {
                    emit TransferFailure(recipients[i], amount, reason);
                }
                unchecked {
                    ++i;
                }
            }

            if (amountTotal < amountLD) {
                srcFrom.call{value: amountLD - amountTotal}("");
            }

            emit HandleMessage(messageType, srcChainId, srcAddress, srcFrom, token, amountLD, keccak256(params));
        } else {
            (address[] memory recipients, uint256[] memory amounts) = abi.decode(params, (address[], uint256[]));

            uint256 amountTotal;
            for (uint256 i; i < recipients.length; ) {
                uint256 amount = amounts[i];
                IERC20(token).safeTransfer(recipients[i], amount);

                amountTotal += amount;
                unchecked {
                    ++i;
                }
            }

            if (amountTotal < amountLD) {
                IERC20(token).safeTransfer(srcFrom, amountLD - amountTotal);
            }

            emit HandleMessage(messageType, srcChainId, srcAddress, srcFrom, token, amountLD, keccak256(params));
        }
    }

    //---------------------------------------------------------------------------
    // FAILSAFE FUNCTIONS
    function retryMessage(
        uint8 messageType,
        uint16 srcChainId,
        address srcAddress,
        address srcFrom,
        uint256 nonce,
        bytes calldata params
    ) external payable override {
        FailedMessage memory message = failedMessages[srcChainId][srcAddress][srcFrom][nonce];
        if (message.paramsHash == bytes32(0)) revert NoStoredMessage();
        if (keccak256(params) != message.paramsHash) revert InvalidPayload();

        delete failedMessages[srcChainId][srcAddress][srcFrom][nonce];

        _handleMessage(messageType, srcChainId, srcAddress, srcFrom, message.token, message.amountLD, params);

        emit RetryMessageSuccess(
            messageType,
            srcChainId,
            srcAddress,
            srcFrom,
            nonce,
            message.token,
            message.amountLD,
            message.paramsHash
        );
    }
}
