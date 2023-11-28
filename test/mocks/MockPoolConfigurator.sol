// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IPoolConfigurator } from "../../src/interfaces/IPoolConfigurator.sol";

contract MockPoolConfigurator is IPoolConfigurator {

    mapping(address => uint256) public supplyCap;
    mapping(address => uint256) public borrowCap;

    function setSupplyCap(address asset, uint256 newSupplyCap) external {
        supplyCap[asset] = newSupplyCap;
    }

    function setBorrowCap(address asset, uint256 newBorrowCap) external {
        borrowCap[asset] = newBorrowCap;
    }

}
