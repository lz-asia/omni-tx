// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IOmniTx {
    error SwapFailure(bytes reason);
    error InsufficientValue();
    error DstChainNotFound(uint16 chainId);
    error NativeNotSupported();
    error PoolNotFound(uint256 poolId);
    error InvalidPoolId(uint256 poolId);
    error InvalidDstPoolId(uint256 poolId);
    error Forbidden();
    error InvalidPayload();
    error InvalidAmount();
    error InvalidParamLengths();
    error CallFailure(address srcFrom, address to, address token, uint256 amount, bytes data, bytes reason);

    event UpdateVault(address indexed _vault);
    event UpdateDstAddress(uint16 indexed dstChainId, address indexed dstAddress);
    event SGReceive(
        uint16 indexed srcChainId,
        bytes srcAddress,
        uint256 indexed nonce,
        address indexed srcFrom,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOut
    );
    event SGReceiveFailure(
        uint16 indexed srcChainId,
        bytes srcAddress,
        uint256 indexed nonce,
        address indexed srcFrom,
        address tokenIn,
        uint256 amountIn,
        bytes reason
    );

    struct TransferParams {
        uint256 poolId;
        uint16 dstChainId;
        uint256 dstPoolId;
        uint256 dstMinAmount;
        address[] dstAdapters;
        bytes[] dstData;
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
    }

    function router() external view returns (address);

    function factory() external view returns (address);

    function vault() external view returns (address);

    function dstAddress(uint16 dstChainId) external view returns (address);

    function estimateFee(
        uint16 dstChainId,
        address[] calldata dstAdapters,
        bytes[] calldata dstData,
        uint256 dstGasForCall,
        uint256 dstNativeAmount,
        address from
    ) external view returns (uint256);

    receive() external payable;

    function updateDstAddress(uint16 dstChainId, address _dstAddress) external;

    function transferNative(
        uint256 amount,
        address[] calldata adapters,
        bytes[] calldata data,
        TransferParams calldata params
    ) external payable;

    function transfer(
        address token,
        uint256 amount,
        address[] calldata adapters,
        bytes[] calldata data,
        TransferParams calldata params
    ) external payable;

    function callAdaptersNative(
        address[] calldata adapters,
        bytes[] calldata data
    ) external payable returns (address _tokenOut, uint256 _amountOut);

    function callAdapters(
        address token,
        uint256 amount,
        address[] calldata adapters,
        bytes[] calldata data
    ) external returns (address _tokenOut, uint256 _amountOut);
}
