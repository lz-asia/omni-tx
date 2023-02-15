// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/ILayerZeroReceiver.sol";
import "../interfaces/ILayerZeroEndpoint.sol";
import "../interfaces/IStargateReceiver.sol";

contract StargateRouterMock is ILayerZeroReceiver {
    using SafeERC20 for IERC20;

    struct lzTxObj {
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
        bytes dstNativeAddr;
    }

    address public lzEndpointMock;
    mapping(uint16 => bytes) public bridgeLookup;
    mapping(uint256 => address) public getPool;

    constructor(address _lzEndpointMock) {
        lzEndpointMock = _lzEndpointMock;
    }

    function setBridge(uint16 chainId, bytes calldata bridgeAddress) external {
        require(bridgeLookup[chainId].length == 0, "Stargate: Bridge already set!");
        bridgeLookup[chainId] = bridgeAddress;
    }

    function createPool(uint256 poolId, address token) external {
        getPool[poolId] = token;
    }

    function quoteLayerZeroFee(
        uint16 dstChainId,
        uint8 functionType,
        bytes calldata to,
        bytes calldata params,
        lzTxObj memory lzTxParams
    ) external view returns (uint256, uint256) {
        return
            ILayerZeroEndpoint(lzEndpointMock).estimateFees(
                dstChainId,
                address(this),
                abi.encode(to, params),
                false,
                _buildLzTxParams(lzTxParams)
            );
    }

    function swap(
        uint16 dstChainId,
        uint256 srcPoolId,
        uint256 dstPoolId,
        address payable refundAddress,
        uint256 amountLD,
        uint256 minAmountLD,
        lzTxObj memory lzTxParams,
        bytes calldata to,
        bytes calldata params
    ) external payable {
        IERC20(getPool[srcPoolId]).safeTransferFrom(msg.sender, address(this), amountLD);

        address toAddress = address(bytes20(to[0:20]));
        ILayerZeroEndpoint(lzEndpointMock).send{value: msg.value}(
            dstChainId,
            bridgeLookup[dstChainId],
            abi.encode(uint8(1), toAddress, dstPoolId, amountLD, minAmountLD, params),
            refundAddress,
            address(0),
            _buildLzTxParams(lzTxParams)
        );
    }

    function _buildLzTxParams(lzTxObj memory lzTxParams) internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(1), lzTxParams.dstGasForCall);
    }

    function lzReceive(
        uint16 srcChainId,
        bytes memory srcAddress,
        uint64 nonce,
        bytes calldata payload
    ) external {
        require(msg.sender == address(lzEndpointMock), "Stargate: only LayerZero endpoint can call lzReceive");
        require(
            srcAddress.length == bridgeLookup[srcChainId].length &&
                keccak256(srcAddress) == keccak256(bridgeLookup[srcChainId]),
            "Stargate: bridge does not match"
        );

        (, address to, uint256 poolId, uint256 amountLD, , bytes memory params) = abi.decode(
            payload,
            (uint8, address, uint256, uint256, uint256, bytes)
        );
        address token = getPool[poolId];
        IERC20(token).safeTransfer(to, amountLD);
        if (params.length > 0) {
            IStargateReceiver(to).sgReceive(srcChainId, srcAddress, nonce, token, amountLD, params);
        }
    }
}
