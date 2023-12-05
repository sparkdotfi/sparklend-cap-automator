// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { PoolLike, PoolConfiguratorLike } from "src/CapAutomator.sol";

contract MockPool is PoolLike, PoolConfiguratorLike {

    mapping(address => uint256) public aTokenTotalSupply;
    mapping(address => uint256) public totalDebt;
    mapping(address => uint256) public supplyCap;
    mapping(address => uint256) public borrowCap;

    function setATokenTotalSupply(address asset, uint256 newATokenTotalSupply) external {
        aTokenTotalSupply[asset] = newATokenTotalSupply;
    }

    function setTotalDebt(address asset, uint256 newTotalDebt) external {
        totalDebt[asset] = newTotalDebt;
    }

    function setSupplyCap(address asset, uint256 newSupplyCap) external {
        supplyCap[asset] = newSupplyCap;
    }

    function setBorrowCap(address asset, uint256 newBorrowCap) external {
        borrowCap[asset] = newBorrowCap;
    }

    function getATokenTotalSupply(address asset) external view returns (uint256) {
        return aTokenTotalSupply[asset];
    }

    function getTotalDebt(address asset) external view returns (uint256) {
        return totalDebt[asset];
    }

    function getReserveCaps(address asset) external view returns (uint256, uint256) {
        return (borrowCap[asset], supplyCap[asset]);
    }
}
