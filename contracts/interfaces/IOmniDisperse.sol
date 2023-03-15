// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IOmniDisperse {
    error DstChainNotFound(uint16 chainId);
    error PoolNotFound(uint256 poolId);
    error Forbidden();
    error NoStoredMessage();
    error InvalidPayload();
    error SwapFailure(bytes reason);

    event UpdateDstAddress(uint16 indexed dstChainId, address indexed dstAddress);
    event UpdateToken(uint256 indexed poolId, address indexed token);
    event TransferFailure(address indexed to, uint256 amount, bytes reason);
    event SGReceive(
        uint16 indexed srcChainId,
        bytes indexed srcAddress,
        uint256 indexed nonce,
        address token,
        uint256 amountLD,
        bytes payload
    );
    event HandleMessage(
        uint8 messageType,
        uint16 indexed srcChainId,
        address indexed srcAddress,
        address indexed srcFrom,
        address token,
        uint256 amountLD,
        bytes32 paramsHash
    );
    event MessageFailed(
        uint16 indexed srcChainId,
        address indexed srcAddress,
        address indexed srcFrom,
        uint256 nonce,
        address token,
        uint256 amountLD,
        bytes params,
        bytes reason
    );
    event RetryMessageSuccess(
        uint8 messageType,
        uint16 indexed srcChainId,
        address indexed srcAddress,
        address indexed srcFrom,
        uint256 nonce,
        address token,
        uint256 amountLD,
        bytes32 paramsHash
    );

    struct TransferERC20Params {
        uint256 poolId;
        uint256 amount;
        uint16 dstChainId;
        uint256 dstPoolId;
        uint256 dstMinAmount;
        address[] dstRecipients;
        uint256[] dstAmounts;
        uint256 gas;
    }

    struct TransferERC20AndSwapToNativeParams {
        uint256 poolId;
        uint256 amount;
        uint16 dstChainId;
        uint256 dstPoolId;
        uint256 dstMinAmount;
        bytes[] swapData;
        address[] dstRecipients;
        uint256[] dstAmounts;
        uint256 gas;
    }

    struct FailedMessage {
        address token;
        uint256 amountLD;
        bytes32 paramsHash;
    }

    function estimateFeeTransferERC20(
        uint16 dstChainId,
        address[] memory dstRecipients,
        uint256[] memory dstAmounts,
        uint256 gas,
        address from
    ) external view returns (uint256);

    function estimateFeeSwapToNative(
        uint16 dstChainId,
        bytes[] memory swapData,
        address[] memory dstRecipients,
        uint256[] memory dstAmounts,
        uint256 gas,
        address from
    ) external view returns (uint256);

    function updateDstAddress(uint16 dstChainId, address _dstAddress) external;

    function transferERC20(TransferERC20Params memory params) external payable;

    function transferERC20AndSwapToNative(TransferERC20AndSwapToNativeParams memory params) external payable;

    function retryMessage(
        uint8 messageType,
        uint16 srcChainId,
        address srcAddress,
        address srcFrom,
        uint256 nonce,
        bytes calldata params
    ) external payable;
}
