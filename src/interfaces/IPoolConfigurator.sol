// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

interface IPoolConfigurator {

    function setSupplyCap(address asset, uint256 newSupplyCap) external;

    function setBorrowCap(address asset, uint256 newBorrowCap) external;

}
