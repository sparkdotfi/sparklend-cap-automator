// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { IACLManager }       from "aave-v3-core/contracts/interfaces/IACLManager.sol";
import { IPool }             from "aave-v3-core/contracts/interfaces/IPool.sol";
import { IPoolConfigurator } from "aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";

import { CapAutomator } from "../src/CapAutomator.sol";

contract CapAutomatorIntegrationTests is Test {

    address public constant POOL_ADDRESSES_PROVIDER = 0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE;
    address public constant POOL                    = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
    address public constant POOL_CONFIG             = 0x542DBa469bdE58FAeE189ffB60C6b49CE60E0738;
    address public constant DATA_PROVIDER           = 0xFc21d6d146E6086B8359705C8b28512a983db0cb;
    address public constant ACL_MANAGER             = 0xdA135Cd78A086025BcdC87B038a1C462032b510C;
    address public constant SPARK_PROXY             = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    address public constant RETH                    = 0xae78736Cd615f374D3085123A210448E74Fc6393;

    CapAutomator public capAutomator;

    IACLManager aclManager = IACLManager(ACL_MANAGER);

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 18_721_430);

        capAutomator = new CapAutomator(POOL_ADDRESSES_PROVIDER);

        capAutomator.transferOwnership(SPARK_PROXY);

        vm.prank(SPARK_PROXY);
        aclManager.addPoolAdmin(address(capAutomator));
    }

    function test_runIntegrationTests() public {
        vm.prank(SPARK_PROXY);
        capAutomator.setSupplyCapConfig({
            asset:                 RETH,
            max:                100_000,
            gap:                  5_000,
            increaseCooldown:         0
        });

        vm.prank(SPARK_PROXY);
        capAutomator.setBorrowCapConfig({
            asset:                 RETH,
            max:                100_000,
            gap:                  5_000,
            increaseCooldown:         0
        });

        capAutomator.exec(RETH);
    }
}
