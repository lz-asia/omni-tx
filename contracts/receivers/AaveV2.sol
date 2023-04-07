// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "../interfaces/IAaveV2.sol";
import "../interfaces/IProtocolDataProvider.sol";
import "../interfaces/ILendingPoolAddressesProvider.sol";
import "../interfaces/ILendingPool.sol";
import "../libraries/RefundUtils.sol";

interface IAToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}

contract AaveV2 is IAaveV2 {
    uint8 private constant DEPOSIT = 1;
    uint8 private constant WITHDRAW = 2;
    uint8 private constant BORROW = 3;
    uint8 private constant REPAY = 4;

    address public immutable omniTx;
    address public immutable protocolDataProvider;
    address public immutable addressesProvider;

    constructor(address _omniTx, address _protocolDataProvider) {
        omniTx = _omniTx;
        protocolDataProvider = _protocolDataProvider;
        addressesProvider = address(IProtocolDataProvider(_protocolDataProvider).ADDRESSES_PROVIDER());
    }

    function otReceive(
        address srcFrom,
        address tokenIn,
        uint256 amountIn,
        bytes calldata data
    ) external payable returns (address tokenOut, uint256 amountOut) {
        if (msg.sender != omniTx) revert Forbidden();

        uint8 action = uint8(bytes1(data[0:1]));
        if (action == DEPOSIT) {
            (tokenOut, amountOut) = _deposit(tokenIn, amountIn);
        } else if (action == WITHDRAW) {
            (tokenOut, amountOut) = _withdraw(tokenIn, address(bytes20(data[1:2])), uint256(bytes32(data[21:53])));
        } else if (action == BORROW) {
            (tokenOut, amountOut) = _borrow(
                address(bytes20(data[1:21])),
                uint256(bytes32(data[21:53])),
                uint8(bytes1(data[53:54])),
                srcFrom
            );
        } else if (action == REPAY) {
            _repay(tokenIn, amountIn, uint8(bytes1(data[1:2])), srcFrom);
        } else revert InvalidAction(action);

        RefundUtils.refundERC20(tokenIn, omniTx, address(0));

        emit OTReceive(srcFrom, tokenIn, amountIn, data);
    }

    function _deposit(address asset, uint256 amountAsset) internal returns (address tokenOut, uint256 amountOut) {
        address pool = ILendingPoolAddressesProvider(addressesProvider).getLendingPool();
        (address aToken, , ) = IProtocolDataProvider(protocolDataProvider).getReserveTokensAddresses(asset);

        uint256 before = IERC20(aToken).balanceOf(omniTx);

        IERC20(asset).approve(pool, amountAsset);
        ILendingPool(pool).deposit(asset, amountAsset, omniTx, 0);
        IERC20(asset).approve(pool, 0);

        return (aToken, IERC20(aToken).balanceOf(omniTx) - before);
    }

    function _withdraw(
        address aToken,
        address asset,
        uint256 amountAsset
    ) internal returns (address tokenOut, uint256 amountOut) {
        address pool = ILendingPoolAddressesProvider(addressesProvider).getLendingPool();
        (address _aToken, , ) = IProtocolDataProvider(protocolDataProvider).getReserveTokensAddresses(asset);
        if (aToken != _aToken) revert InvalidAsset(asset);

        uint256 before = IERC20(asset).balanceOf(omniTx);

        ILendingPool(pool).withdraw(asset, amountAsset, omniTx);

        return (asset, IERC20(asset).balanceOf(omniTx) - before);
    }

    function _borrow(
        address asset,
        uint256 amountAsset,
        uint256 interestRateMode,
        address onBehalfOf
    ) internal returns (address tokenOut, uint256 amountOut) {
        address pool = ILendingPoolAddressesProvider(addressesProvider).getLendingPool();

        // WARNING: onBehalfOf must have given enough allowance to this contract on the debt token
        ILendingPool(pool).borrow(asset, amountAsset, interestRateMode, 0, onBehalfOf);

        return (asset, RefundUtils.refundERC20(asset, omniTx, address(0)));
    }

    function _repay(
        address asset,
        uint256 amountAsset,
        uint256 interestRateMode,
        address onBehalfOf
    ) internal {
        address pool = ILendingPoolAddressesProvider(addressesProvider).getLendingPool();

        IERC20(asset).approve(pool, amountAsset);
        ILendingPool(pool).repay(asset, amountAsset, interestRateMode, onBehalfOf);
        IERC20(asset).approve(pool, 0);
    }
}
