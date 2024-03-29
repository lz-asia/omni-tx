// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IStargateReceiver.sol";
import "./interfaces/IOmniTx.sol";
import "./interfaces/IStargateRouter.sol";
import "./interfaces/IStargateEthVault.sol";
import "./interfaces/IStargateFactory.sol";
import "./interfaces/IStargatePool.sol";
import "./interfaces/IOmniTxAdapter.sol";
import "./libraries/RefundUtils.sol";
import "./ERC20Vault.sol";

contract OmniTx is Ownable, ReentrancyGuard, IStargateReceiver, IOmniTx {
    using SafeERC20 for IERC20;
    using Address for address payable;

    address public immutable router;
    address public immutable stargateEthVault;
    address public immutable factory;
    address public vault;
    mapping(uint16 => address) public dstAddress;

    constructor(address _router, address _stargateEthVault, address _owner) {
        router = _router;
        stargateEthVault = _stargateEthVault;
        factory = IStargateRouter(_router).factory();
        address _vault = address(new ERC20Vault(address(this)));
        vault = _vault;
        emit UpdateVault(_vault);
        transferOwnership(_owner);
    }

    function estimateFee(
        uint16 dstChainId,
        address[] calldata dstAdapters,
        bytes[] calldata dstData,
        uint256 dstGasForCall,
        uint256 dstNativeAmount,
        address from
    ) external view returns (uint256) {
        address dst = dstAddress[dstChainId];
        if (dst == address(0)) revert DstChainNotFound(dstChainId);

        (uint256 fee, ) = IStargateRouter(router).quoteLayerZeroFee(
            dstChainId,
            1 /*TYPE_SWAP_REMOTE*/,
            abi.encodePacked(dst),
            abi.encode(from, dstAdapters, dstData),
            IStargateRouter.lzTxObj(dstGasForCall, dstNativeAmount, abi.encodePacked(from))
        );
        return fee;
    }

    receive() external payable {}

    function updateVault(address _vault) external onlyOwner {
        vault = _vault;
        emit UpdateVault(_vault);
    }

    function updateDstAddress(uint16 dstChainId, address _dstAddress) external onlyOwner {
        dstAddress[dstChainId] = _dstAddress;
        emit UpdateDstAddress(dstChainId, _dstAddress);
    }

    function transferNative(
        uint256 amount,
        address[] calldata adapters,
        bytes[] calldata data,
        TransferParams calldata params
    ) external payable {
        if (msg.value < amount) revert InsufficientValue();
        (address tokenOut, uint256 amountOut) = _callAdapters(address(0), amount, adapters, data, false, msg.sender);
        _transfer(tokenOut, amountOut, params, msg.value - amount);
    }

    function transfer(
        address token,
        uint256 amount,
        address[] calldata adapters,
        bytes[] calldata data,
        TransferParams calldata params
    ) external payable {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        (address tokenOut, uint256 amountOut) = _callAdapters(token, amount, adapters, data, false, msg.sender);
        _transfer(tokenOut, amountOut, params, msg.value);
    }

    function _transfer(address token, uint256 amount, TransferParams calldata params, uint256 fee) internal {
        address dst = dstAddress[params.dstChainId];
        if (dst == address(0)) revert DstChainNotFound(params.dstChainId);

        bool native = token == address(0);
        if (native) {
            if (stargateEthVault == address(0)) revert NativeNotSupported();
            IStargateEthVault(stargateEthVault).deposit{value: amount}();
            IStargateEthVault(stargateEthVault).approve(router, amount);
        } else {
            address pool = IStargateFactory(factory).getPool(params.poolId);
            if (pool == address(0)) revert PoolNotFound(params.poolId);
            if (token != IStargatePool(pool).token()) revert InvalidPoolId(params.poolId);
            IERC20(token).approve(router, amount);
        }

        IStargateRouter(router).swap{value: fee}(
            params.dstChainId,
            params.poolId,
            params.dstPoolId,
            payable(msg.sender),
            amount,
            params.dstMinAmount,
            IStargateRouter.lzTxObj(params.dstGasForCall, params.dstNativeAmount, abi.encodePacked(msg.sender)),
            abi.encodePacked(dst),
            abi.encode(msg.sender, params.dstAdapters, params.dstData)
        );
        if (!native) {
            IERC20(token).approve(router, 0);
        }

        RefundUtils.refundERC20(token, msg.sender, address(0));
        RefundUtils.refundNative(msg.sender, address(0));
    }

    //---------------------------------------------------------------------------
    // RECEIVER FUNCTIONS
    function estimateGas(
        address swapTo,
        bytes calldata swapData,
        uint16 srcChainId,
        bytes calldata srcAddress,
        uint256 nonce,
        address token,
        uint256 amountLD,
        bytes calldata payload
    ) external payable returns (uint256 gasSpent) {
        (bool ok, bytes memory reason) = swapTo.call{value: msg.value}(swapData);
        if (!ok) revert SwapFailure(reason);

        uint256 gas = gasleft();
        this.onSGReceive(srcChainId, srcAddress, nonce, token, amountLD, payload);
        return gas - gasleft();
    }

    function sgReceive(
        uint16 srcChainId,
        bytes calldata srcAddress,
        uint256 nonce,
        address token,
        uint256 amountLD,
        bytes calldata payload
    ) external nonReentrant {
        if (msg.sender != router) revert Forbidden();

        address srcFrom = payload.length < 32 ? address(0) : abi.decode(payload, (address));
        try this.onSGReceive(srcChainId, srcAddress, nonce, token, amountLD, payload) returns (
            address tokenOut,
            uint256 amountOut
        ) {
            emit SGReceive(srcChainId, srcAddress, nonce, srcFrom, token, amountLD, tokenOut, amountOut);
        } catch (bytes memory reason) {
            address refundAddress = srcFrom == address(0) ? vault : abi.decode(payload, (address));
            RefundUtils.refundERC20(token, refundAddress, vault);

            emit SGReceiveFailure(srcChainId, srcAddress, nonce, srcFrom, token, amountLD, reason);
        }
    }

    function onSGReceive(
        uint16,
        bytes calldata,
        uint256,
        address tokenIn,
        uint256 amountIn,
        bytes calldata payload
    ) external returns (address tokenOut, uint256 amountOut) {
        if (msg.sender != address(this)) revert Forbidden();

        (address srcFrom, address[] memory adapters, bytes[] memory data) = abi.decode(
            payload,
            (address, address[], bytes[])
        );
        (tokenOut, amountOut) = _callAdapters(tokenIn, amountIn, adapters, data, true, srcFrom);

        RefundUtils.refundERC20(tokenOut, srcFrom, vault);
        RefundUtils.refundNative(srcFrom, vault);
    }

    function callAdaptersNative(
        address[] calldata adapters,
        bytes[] calldata data
    ) external payable returns (address tokenOut, uint256 amountOut) {
        (tokenOut, amountOut) = _callAdapters(address(0), msg.value, adapters, data, false, msg.sender);

        RefundUtils.refundERC20(tokenOut, msg.sender, vault);
        RefundUtils.refundNative(msg.sender, vault);
    }

    function callAdapters(
        address token,
        uint256 amount,
        address[] calldata adapters,
        bytes[] calldata data
    ) external returns (address tokenOut, uint256 amountOut) {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        (tokenOut, amountOut) = _callAdapters(token, amount, adapters, data, false, msg.sender);

        RefundUtils.refundERC20(tokenOut, msg.sender, vault);
        RefundUtils.refundNative(msg.sender, vault);
    }

    function _callAdapters(
        address tokenIn,
        uint256 amountIn,
        address[] memory adapters,
        bytes[] memory data,
        bool _fallback,
        address from
    ) internal returns (address _tokenOut, uint256 _amountOut) {
        if (amountIn == 0) revert InvalidAmount();
        if (adapters.length != data.length) revert InvalidParamLengths();

        address refundFallback = _fallback ? vault : address(0);

        for (uint256 i; i < adapters.length; ) {
            address to = adapters[i];
            bool native = tokenIn == address(0);
            if (!native) {
                IERC20(tokenIn).safeTransfer(to, amountIn);
            }
            try IOmniTxAdapter(to).otReceive{value: native ? amountIn : 0}(from, tokenIn, amountIn, data[i]) returns (
                address tokenOut,
                uint256 amountOut
            ) {
                if (!native) {
                    RefundUtils.refundERC20(tokenIn, from, refundFallback);
                }
                (tokenIn, amountIn) = (tokenOut, amountOut);
            } catch (bytes memory reason) {
                revert CallFailure(from, to, tokenIn, amountIn, data[i], reason);
            }
            unchecked {
                ++i;
            }
        }

        return (tokenIn, amountIn);
    }
}
