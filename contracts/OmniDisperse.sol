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
    using Address for address payable;

    uint8 public constant TYPE_TRANSFER_ERC20 = 0;
    uint8 public constant TYPE_SWAP_TO_NATIVE = 1;

    address public immutable router;
    address public immutable factory;
    mapping(uint16 => address) public dstAddress;

    constructor(address _router) {
        router = _router;
        factory = IStargateRouter(_router).factory();
    }

    receive() external payable {}

    function estimateFeeTransferERC20(
        uint16 dstChainId,
        address[] calldata dstRecipients,
        uint256[] calldata dstAmounts,
        uint256 gas,
        uint256 dstNativeAmount,
        address from
    ) external view returns (uint256) {
        address dst = dstAddress[dstChainId];
        if (dst == address(0)) revert DstChainNotFound(dstChainId);

        (uint256 fee, ) = IStargateRouter(router).quoteLayerZeroFee(
            dstChainId,
            1, /*TYPE_SWAP_REMOTE*/
            abi.encodePacked(dst),
            abi.encodePacked(TYPE_TRANSFER_ERC20, from, abi.encode(dstRecipients, dstAmounts)),
            IStargateRouter.lzTxObj(gas, dstNativeAmount, abi.encodePacked(from))
        );
        return fee;
    }

    function estimateFeeSwapToNative(
        uint16 dstChainId,
        bytes[] calldata swapData,
        address[] calldata dstRecipients,
        uint256[] calldata dstAmounts,
        uint256 gas,
        uint256 dstNativeAmount,
        address from
    ) external view returns (uint256) {
        address dst = dstAddress[dstChainId];
        if (dst == address(0)) revert DstChainNotFound(dstChainId);

        (uint256 fee, ) = IStargateRouter(router).quoteLayerZeroFee(
            dstChainId,
            1, /*TYPE_SWAP_REMOTE*/
            abi.encodePacked(dst),
            abi.encodePacked(TYPE_SWAP_TO_NATIVE, from, abi.encode(swapData, dstRecipients, dstAmounts)),
            IStargateRouter.lzTxObj(gas, dstNativeAmount, abi.encodePacked(from))
        );
        return fee;
    }

    function updateDstAddress(uint16 dstChainId, address _dstAddress) external onlyOwner {
        dstAddress[dstChainId] = _dstAddress;
        emit UpdateDstAddress(dstChainId, _dstAddress);
    }

    function transferERC20(TransferERC20Params calldata params) external payable {
        _transferERC20(params, payable(msg.sender), msg.value);
    }

    function _transferERC20(
        TransferERC20Params calldata params,
        address payable from,
        uint256 fee
    ) internal {
        if (params.dstRecipients.length != params.dstAmounts.length) revert LengthsAreNotEqual();

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
            IStargateRouter.lzTxObj(params.gas, params.dstNativeAmount, abi.encodePacked(from)),
            abi.encodePacked(dst),
            abi.encodePacked(TYPE_TRANSFER_ERC20, from, abi.encode(params.dstRecipients, params.dstAmounts))
        );
    }

    function transferERC20AndSwapToNative(TransferERC20AndSwapToNativeParams calldata params) external payable {
        _transferERC20AndSwapToNative(params, payable(msg.sender), msg.value);
    }

    function _transferERC20AndSwapToNative(
        TransferERC20AndSwapToNativeParams calldata params,
        address payable from,
        uint256 fee
    ) internal {
        if (params.dstRecipients.length != params.dstAmounts.length) revert LengthsAreNotEqual();

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
            IStargateRouter.lzTxObj(params.gas, params.dstNativeAmount, abi.encodePacked(from)),
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
    ) external {
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
            emit HandleMessageFailed(srcChainId, _srcAddress, srcFrom, nonce, token, amountLD, params, reason);
        }
        uint256 amountRemained = IERC20(token).balanceOf(address(this));
        if (amountRemained != 0) {
            IERC20(token).safeTransfer(srcFrom, amountRemained);
        }

        amountRemained = address(this).balance;
        if (amountRemained != 0) {
            payable(srcFrom).sendValue(amountRemained);
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
        bytes calldata params
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
        bytes calldata params
    ) internal {
        if (messageType == TYPE_SWAP_TO_NATIVE) {
            (bytes[] memory swapData, address[] memory recipients, uint256[] memory amounts) = abi.decode(
                params,
                (bytes[], address[], uint256[])
            );
            uint256 rLength = recipients.length;
            if (rLength != amounts.length) revert LengthsAreNotEqual();

            uint256 sLength = swapData.length;
            for (uint256 i; i < sLength; ) {
                (address to, bytes memory data) = abi.decode(swapData[i], (address, bytes));
                (bool ok, bytes memory reason) = to.call(data);
                if (!ok) revert SwapFailure(reason);
                unchecked {
                    ++i;
                }
            }

            for (uint256 i; i < rLength; ) {
                uint256 amount = amounts[i];
                if (amount != 0) payable(recipients[i]).sendValue(amount);
                unchecked {
                    ++i;
                }
            }
        } else {
            (address[] memory recipients, uint256[] memory amounts) = abi.decode(params, (address[], uint256[]));
            uint256 length = recipients.length;
            if (length != amounts.length) revert LengthsAreNotEqual();

            for (uint256 i; i < length; ) {
                uint256 amount = amounts[i];
                if (amount != 0) IERC20(token).safeTransfer(recipients[i], amount);
                unchecked {
                    ++i;
                }
            }
        }
        emit HandleMessage(messageType, srcChainId, srcAddress, srcFrom, token, amountLD, keccak256(params));
    }
}
