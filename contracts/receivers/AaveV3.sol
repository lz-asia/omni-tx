// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@aave/core-v3/contracts/interfaces/IPoolDataProvider.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@aave/core-v3/contracts/interfaces/ICreditDelegationToken.sol";
import "../interfaces/IAaveV3.sol";
import "../libraries/RefundUtils.sol";

interface IAToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}

contract AaveV3 is IAaveV3 {
    uint8 private constant SUPPLY = 1;
    uint8 private constant WITHDRAW = 2;
    uint8 private constant BORROW = 3;
    uint8 private constant REPAY = 4;

    address public immutable omniTx;
    address public immutable addressesProvider;

    constructor(address _omniTx, address _addressesProvider) {
        omniTx = _omniTx;
        addressesProvider = _addressesProvider;
    }

    /**
     *  collateral -> supply() -> aToken
     *  aToken -> withdraw() -> collateral
     *  borrow() -> asset
     *  asset -> repay()
     */
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
            (tokenOut, amountOut) = _withdraw(tokenIn, uint256(bytes32(data[1:33])));
        } else if (action == BORROW) {
            (tokenOut, amountOut) = _borrow(
                tokenIn,
                uint256(bytes32(data[1:33])),
                uint8(bytes1(data[33:34])),
                srcFrom,
                uint256(bytes32(data[34:66])),
                uint8(bytes1(data[66:67])),
                bytes32(data[67:99]),
                bytes32(data[99:131])
            );
        } else if (action == REPAY) {
            _repay(tokenIn, uint256(bytes32(data[1:33])), uint8(bytes1(data[33:34])), srcFrom);
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

    function _withdraw(address tokenIn, uint256 amountAsset) internal returns (address tokenOut, uint256 amountOut) {
        address asset = IAToken(tokenIn).UNDERLYING_ASSET_ADDRESS();
        address pool = IPoolAddressesProvider(addressesProvider).getPool();

        uint256 before = IERC20(asset).balanceOf(omniTx);

        IPool(pool).withdraw(asset, amountAsset, omniTx);

        RefundUtils.refundERC20(tokenIn, omniTx, address(0));

        return (asset, IERC20(asset).balanceOf(omniTx) - before);
    }

    function _borrow(
        address tokenIn,
        uint256 amountAsset,
        uint256 interestRateMode,
        address onBehalfOf,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal returns (address tokenOut, uint256 amountOut) {
        address asset = IAToken(tokenIn).UNDERLYING_ASSET_ADDRESS();
        address pool = IPoolAddressesProvider(addressesProvider).getPool();
        address dataProvider = IPoolAddressesProvider(addressesProvider).getPoolDataProvider();
        (, address sdToken, address vdToken) = IPoolDataProvider(dataProvider).getReserveTokensAddresses(asset);
        address dToken = interestRateMode == 1 ? sdToken : vdToken;

        ICreditDelegationToken(dToken).delegationWithSig(onBehalfOf, address(this), amountAsset, deadline, v, r, s);

        IPool(pool).borrow(asset, amountAsset, interestRateMode, 0, onBehalfOf);

        RefundUtils.refundERC20(tokenIn, omniTx, address(0));
        return (asset, RefundUtils.refundERC20(asset, omniTx, address(0)));
    }

    function _repay(
        address tokenIn,
        uint256 amountAsset,
        uint256 interestRateMode,
        address onBehalfOf
    ) internal {
        address asset = IAToken(tokenIn).UNDERLYING_ASSET_ADDRESS();
        address pool = IPoolAddressesProvider(addressesProvider).getPool();

        IERC20(asset).approve(pool, amountAsset);
        IPool(pool).repay(asset, amountAsset, interestRateMode, onBehalfOf);
        IERC20(asset).approve(pool, 0);

        RefundUtils.refundERC20(tokenIn, omniTx, address(0));
    }
}
