// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IOmniDisperse {
    error DstChainNotFound(uint16 chainId);
    error TokenNotFound(uint256 poolId);
    error Forbidden();

    event UpdateDstAddress(uint16 indexed dstChainId, address indexed dstAddress);
    event UpdateToken(uint256 indexed poolId, address indexed token);
    event SGReceive(
        uint16 indexed srcChainId,
        bytes indexed srcAddress,
        uint256 indexed nonce,
        address token,
        uint256 amountLD,
        bytes payload
    );
    event HandleMessage(
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
        uint16 indexed srcChainId,
        address indexed srcAddress,
        address indexed srcFrom,
        uint256 nonce,
        address token,
        uint256 amountLD,
        bytes32 paramsHash
    );
    event CancelFailedMessage(
        uint16 indexed srcChainId,
        address indexed srcAddress,
        address indexed srcFrom,
        uint256 nonce
    );
}
