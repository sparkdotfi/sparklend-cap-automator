// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { CapAutomator, PoolConfiguratorLike, PoolLike } from "src/CapAutomator.sol";

contract CapAutomatorHarness is CapAutomator {

    constructor(address poolConfigurator, address pool)
        CapAutomator(poolConfigurator, pool) {}

    function _calculateNewCapExternal(
        CapConfig memory capConfig,
        uint256 currentState,
        uint256 currentCap
    ) public view returns (uint256) {
        return super._calculateNewCap(
            capConfig,
            currentState,
            currentCap
        );
    }

    function _updateSupplyCapConfigExternal(address asset) public returns (uint256) {
        return super._updateSupplyCapConfig(asset);
    }

    function _updateBorrowCapConfigExternal(address asset) public returns (uint256) {
        return super._updateBorrowCapConfig(asset);
    }

}
