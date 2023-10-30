// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
import "../interfaces/IStargateFactory.sol";
import "./StargatePoolMock.sol";

contract StargateFactoryMock is IStargateFactory {
    //---------------------------------------------------------------------------
    // VARIABLES
    mapping(uint256 => address) public override getPool; // poolId -> PoolInfo
    address[] public override allPools;

    function allPoolsLength() external view override returns (uint256) {
        return allPools.length;
    }

    function createPool(uint256 _poolId, address _token) public returns (address poolAddress) {
        require(address(getPool[_poolId]) == address(0x0), "Stargate: Pool already created");

        StargatePoolMock pool = new StargatePoolMock(_poolId, _token);
        poolAddress = address(pool);
        getPool[_poolId] = poolAddress;
        allPools.push(poolAddress);
    }
}
