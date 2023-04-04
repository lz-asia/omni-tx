// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IOmniTx {
    error SwapFailure(bytes reason);
    error DstChainNotFound(uint16 chainId);
    error PoolNotFound(uint256 poolId);
    error InvalidPoolId(uint256 poolId);
    error Forbidden();
    error InvalidParamLengths();

    event UpdateWallet(address indexed _wallet);
    event UpdateDstAddress(uint16 indexed dstChainId, address indexed dstAddress);
    event CallSuccess(address indexed srcFrom, address indexed to, address indexed token, uint256 amount);
    event CallFailure(
        address indexed srcFrom,
        address indexed to,
        address indexed token,
        uint256 amount,
        bytes data,
        bytes reason
    );
    event SGReceive(
        uint16 indexed srcChainId,
        bytes indexed srcAddress,
        uint256 indexed nonce,
        address srcFrom,
        address token,
        uint256 amountLD
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

    function transferERC20(
        address token,
        uint256 amount,
        address[] calldata receivers,
        bytes[] calldata data,
        TransferParams calldata params
    ) external payable;
}
