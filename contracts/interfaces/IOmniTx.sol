// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IOmniTx {
    error SwapFailure(bytes reason);
    error DstChainNotFound(uint16 chainId);
    error PoolNotFound(uint256 poolId);
    error InvalidPoolId(uint256 poolId);
    error Forbidden();
    error InvalidPayload();
    error InvalidParamLengths();
    error CallFailure(address srcFrom, address to, address token, uint256 amount, bytes data, bytes reason);

    event UpdateWallet(address indexed _wallet);
    event UpdateDstAddress(uint16 indexed dstChainId, address indexed dstAddress);
    event SGReceive(
        uint16 indexed srcChainId,
        bytes srcAddress,
        uint256 indexed nonce,
        address indexed srcFrom,
        address token,
        uint256 amountLD
    );
    event SGReceiveFailure(
        uint16 indexed srcChainId,
        bytes srcAddress,
        uint256 indexed nonce,
        address indexed srcFrom,
        address token,
        uint256 amountLD,
        bytes reason
    );

    struct TransferParams {
        uint256 poolId;
        uint16 dstChainId;
        uint256 dstPoolId;
        uint256 dstMinAmount;
        address[] dstReceivers;
        bytes[] dstData;
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
    }

    function router() external view returns (address);

    function factory() external view returns (address);

    function wallet() external view returns (address);

    function dstAddress(uint16 dstChainId) external view returns (address);

    function estimateFee(
        uint16 dstChainId,
        address[] calldata dstReceivers,
        bytes[] calldata dstData,
        uint256 dstGasForCall,
        uint256 dstNativeAmount,
        address from
    ) external view returns (uint256);

    receive() external payable;

    function updateDstAddress(uint16 dstChainId, address _dstAddress) external;

    function transferNative(
        uint256 amount,
        address[] calldata receivers,
        bytes[] calldata data,
        TransferParams calldata params
    ) external payable;

    function transfer(
        address token,
        uint256 amount,
        address[] calldata receivers,
        bytes[] calldata data,
        TransferParams calldata params
    ) external payable;

    function callReceiversNative(address[] calldata receivers, bytes[] calldata data)
        external
        payable
        returns (address _tokenOut, uint256 _amountOut);

    function callReceivers(
        address token,
        uint256 amount,
        address[] calldata receivers,
        bytes[] calldata data
    ) external returns (address _tokenOut, uint256 _amountOut);
}
