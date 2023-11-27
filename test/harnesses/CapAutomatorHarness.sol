// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IPoolConfigurator } from "../../src/interfaces/IPoolConfigurator.sol";
import { IDataProvider }     from "../../src/interfaces/IDataProvider.sol";

import { CapAutomator } from "src/CapAutomator.sol";

contract CapAutomatorHarness is CapAutomator {

    constructor(IPoolConfigurator poolConfigurator, IDataProvider dataProvider)
        CapAutomator(poolConfigurator, dataProvider) {}

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
