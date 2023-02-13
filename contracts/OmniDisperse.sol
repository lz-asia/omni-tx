// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IStargateReceiver.sol";
import "./interfaces/IStargateRouter.sol";
import "./interfaces/IOmniDisperse.sol";
import "./libraries/ExcessivelySafeCall.sol";

contract OmniDisperse is Ownable, IStargateReceiver, IOmniDisperse {
    using SafeERC20 for IERC20;
    using ExcessivelySafeCall for address;

    struct FailedMessage {
        address token;
        uint256 amountLD;
        bytes32 paramsHash;
    }

    address public immutable sgRouter;
    mapping(uint16 => address) public dstAddress;
    mapping(uint16 => uint256) public gasLookup;
    mapping(uint256 => address) public tokenLookup;
    mapping(uint16 => mapping(address => mapping(address => mapping(uint256 => FailedMessage)))) public failedMessages; // srcChainId -> srcAddress -> srcFrom -> nonce -> FailedMessage

    constructor(address _sgRouter) {
        sgRouter = _sgRouter;
    }

    function estimateFee(
        uint16 dstChainId,
        address[] memory dstRecipients,
        uint256[] memory dstAmounts,
        address from
    ) external view returns (uint256) {
        address dst = dstAddress[dstChainId];
        if (dst == address(0)) revert DstChainNotFound(dstChainId);

        uint256 dstMinAmount;
        for (uint256 i; i < dstAmounts.length; ) {
            dstMinAmount += dstAmounts[i];
            unchecked {
                ++i;
            }
        }

        (uint256 fee, ) = IStargateRouter(sgRouter).quoteLayerZeroFee(
            dstChainId,
            1, /*TYPE_SWAP_REMOTE*/
            abi.encodePacked(dst),
            abi.encodePacked(from, abi.encode(dstRecipients), abi.encode(dstAmounts)),
            IStargateRouter.lzTxObj(gasLookup[dstChainId], 0, "0x")
        );
        return fee;
    }

    function updateDstAddress(uint16 dstChainId, address _dstAddress) external onlyOwner {
        dstAddress[dstChainId] = _dstAddress;
        emit UpdateDstAddress(dstChainId, _dstAddress);
    }

    function updateToken(uint256 poolId, address token) external onlyOwner {
        tokenLookup[poolId] = token;
        emit UpdateToken(poolId, token);
    }

    function transfer(
        uint16 dstChainId,
        uint256 poolId,
        address payable refundAddress,
        uint256 amount,
        address[] memory dstRecipients,
        uint256[] memory dstAmounts
    ) external payable {
        _transfer(dstChainId, poolId, refundAddress, amount, dstRecipients, dstAmounts, msg.sender, msg.value);
    }

    function _transfer(
        uint16 dstChainId,
        uint256 poolId,
        address payable refundAddress,
        uint256 amount,
        address[] memory dstRecipients,
        uint256[] memory dstAmounts,
        address from,
        uint256 fee
    ) internal {
        address dst = dstAddress[dstChainId];
        if (dst == address(0)) revert DstChainNotFound(dstChainId);
        address token = tokenLookup[poolId];
        if (token == address(0)) revert TokenNotFound(poolId);

        uint256 dstMinAmount;
        for (uint256 i; i < dstAmounts.length; ) {
            dstMinAmount += dstAmounts[i];
            unchecked {
                ++i;
            }
        }

        IERC20(token).approve(sgRouter, amount);
        IStargateRouter(sgRouter).swap{value: fee}(
            dstChainId,
            poolId,
            poolId,
            refundAddress,
            amount,
            dstMinAmount,
            IStargateRouter.lzTxObj(gasLookup[dstChainId], 0, "0x"),
            abi.encodePacked(dst),
            abi.encodePacked(from, abi.encode(dstRecipients, dstAmounts))
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
        if (msg.sender != sgRouter) revert Forbidden();

        address _srcAddress = address(bytes20(srcAddress[0:20]));
        address srcFrom = address(bytes20(payload[0:20]));
        bytes memory params = payload[20:];
        (bool success, bytes memory reason) = address(this).excessivelySafeCall(
            gasleft(),
            150,
            abi.encodeWithSelector(
                this.handleMessage.selector,
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
        uint16 srcChainId,
        address srcAddress,
        address srcFrom,
        address token,
        uint256 amountLD,
        bytes memory params
    ) public {
        if (msg.sender != address(this)) revert Forbidden();

        (address[] memory recipients, uint256[] memory amounts) = abi.decode(params, (address[], uint256[]));
        for (uint256 i; i < recipients.length; ) {
            IERC20(token).safeTransfer(recipients[i], amounts[i]);

            unchecked {
                ++i;
            }
        }

        // TODO: transfer back unused token to srcFrom

        emit HandleMessage(srcChainId, srcAddress, srcFrom, token, amountLD, keccak256(params));
    }
}
