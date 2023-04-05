// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@aave/core-v3/contracts/interfaces/IPoolDataProvider.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "../interfaces/IAaveV3.sol";
import "../libraries/RefundUtils.sol";

interface IAToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}

contract AaveV3 is IAaveV3 {
    uint8 private constant SUPPLY = 1;
    uint8 private constant WITHDRAW = 2;
    uint8 private constant REPAY = 3;
    uint8 private constant REPAY_AND_WITHDRAW = 4;

    address public immutable omniTx;
    address public immutable addressesProvider;

    constructor(address _omniTx, address _addressesProvider) {
        omniTx = _omniTx;
        addressesProvider = _addressesProvider;
    }

    function otReceive(
        address srcFrom,
        address tokenIn,
        uint256 amountIn,
        bytes calldata data
    ) external payable returns (address tokenOut, uint256 amountOut) {
        if (msg.sender != omniTx) revert Forbidden();

        uint8 action = uint8(bytes1(data[0:1]));
        if (action == SUPPLY) {
            (tokenOut, amountOut) = _supply(tokenIn, amountIn);
        } else if (action == WITHDRAW) {
            uint256 amountAsset = uint256(bytes32(data[1:33]));
            (tokenOut, amountOut) = _withdraw(tokenIn, amountAsset, srcFrom);
        } else if (action == REPAY) {
            // TODO
        } else if (action == REPAY_AND_WITHDRAW) {
            // TODO
        } else revert InvalidAction(action);

        emit OTReceive(srcFrom, tokenIn, amountIn, data);
    }

    function _supply(address tokenIn, uint256 amountIn) internal returns (address tokenOut, uint256 amountOut) {
        address pool = IPoolAddressesProvider(addressesProvider).getPool();
        address dataProvider = IPoolAddressesProvider(addressesProvider).getPoolDataProvider();
        (address aToken, , ) = IPoolDataProvider(dataProvider).getReserveTokensAddresses(tokenIn);

        uint256 before = IERC20(tokenOut).balanceOf(omniTx);

        IERC20(tokenIn).approve(pool, amountIn);
        IPool(pool).supply(tokenIn, amountIn, omniTx, 0);
        IERC20(tokenIn).approve(pool, 0);

        return (aToken, IERC20(tokenOut).balanceOf(omniTx) - before);
    }

    function _withdraw(
        address tokenIn,
        uint256 amountAsset,
        address refundAddress
    ) internal returns (address tokenOut, uint256 amountOut) {
        address asset = IAToken(tokenIn).UNDERLYING_ASSET_ADDRESS();
        address pool = IPoolAddressesProvider(addressesProvider).getPool();

        uint256 before = IERC20(asset).balanceOf(omniTx);

        IPool(pool).withdraw(asset, amountAsset, omniTx);

        RefundUtils.refundERC20(tokenIn, refundAddress, address(0));

        return (asset, IERC20(asset).balanceOf(omniTx) - before);
    }
}
