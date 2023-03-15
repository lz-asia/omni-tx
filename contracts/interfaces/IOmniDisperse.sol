// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IOmniDisperse {
    error DstChainNotFound(uint16 chainId);
    error PoolNotFound(uint256 poolId);
    error Forbidden();
    error LengthsAreNotEqual();
    error SwapFailure(bytes reason);

    event UpdateDstAddress(uint16 indexed dstChainId, address indexed dstAddress);
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
    event HandleMessageFailed(
        uint16 indexed srcChainId,
        address indexed srcAddress,
        address indexed srcFrom,
        uint256 nonce,
        address token,
        uint256 amountLD,
        bytes params,
        bytes reason
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

    function estimateFeeTransferERC20(
        uint16 dstChainId,
        address[] calldata dstRecipients,
        uint256[] calldata dstAmounts,
        uint256 gas,
        address from
    ) external view returns (uint256);

    function estimateFeeSwapToNative(
        uint16 dstChainId,
        bytes[] calldata swapData,
        address[] calldata dstRecipients,
        uint256[] calldata dstAmounts,
        uint256 gas,
        address from
    ) external view returns (uint256);

    function updateDstAddress(uint16 dstChainId, address _dstAddress) external;

    function transferERC20(TransferERC20Params calldata params) external payable;

    function transferERC20AndSwapToNative(TransferERC20AndSwapToNativeParams calldata params) external payable;
}
