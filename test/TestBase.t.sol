// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.22;

import { Test } from "../lib/forge-std/src/Test.sol";

import { MockPool }                  from "./mocks/MockPool.sol";
import { MockPoolAddressesProvider } from "./mocks/MockPoolAddressesProvider.sol";
import { MockPoolConfigurator }      from "./mocks/MockPoolConfigurator.sol";
import { MockToken }                 from "./mocks/MockToken.sol";

import { CapAutomatorHarness } from "./harnesses/CapAutomatorHarness.sol";

import { CapAutomator } from "../src/CapAutomator.sol";

contract CapAutomatorUnitTestBase is Test {

    MockPoolAddressesProvider internal mockPoolAddressesProvider;
    MockPool                  internal mockPool;
    MockPoolConfigurator      internal mockPoolConfigurator;
    MockToken                 internal mockToken;


    address internal admin        = makeAddr("admin");
    address internal asset        = makeAddr("asset");
    address internal unauthorized = makeAddr("unauthorized");
    address internal updater1     = makeAddr("updater1");
    address internal updater2     = makeAddr("updater2");

    CapAutomator        internal capAutomator;
    CapAutomatorHarness internal capAutomatorHarness;

    bytes32 internal DEFAULT_ADMIN_ROLE;
    bytes32 internal UPDATE_ROLE;

    function setUp() public virtual {
        mockPool                  = new MockPool();
        mockPoolConfigurator      = new MockPoolConfigurator(address(mockPool));
        mockPoolAddressesProvider = new MockPoolAddressesProvider(address(mockPool), address(mockPoolConfigurator));

        mockPool.__setSupplyCap(7_000);

        MockToken(mockPool.aToken()).__setDecimals(18);
        mockPool.__setATokenScaledTotalSupply(5_700e18);
        mockPool.__setAccruedToTreasury(50e18);
        mockPool.__setLiquidityIndex(1.2e27);
        // (aToken. scaledTotalSupply + accruedToTreasury) * liquidityIndex = 6_900e18

        mockPool.__setBorrowCap(4_000);

        MockToken(mockPool.debtToken()).__setDecimals(18);
        mockPool.__setTotalDebt(3_900e18);

        capAutomator = new CapAutomator(address(mockPoolAddressesProvider), admin, updater1);

        DEFAULT_ADMIN_ROLE = capAutomator.DEFAULT_ADMIN_ROLE();
        UPDATE_ROLE        = capAutomator.UPDATE_ROLE();

        vm.prank(admin);
        capAutomator.grantRole(UPDATE_ROLE, updater2);

        capAutomatorHarness = new CapAutomatorHarness(
            address(mockPoolAddressesProvider),
            admin,
            updater1
        );
    }

}
