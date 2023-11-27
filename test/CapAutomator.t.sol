// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { IPoolConfigurator } from "../src/interfaces/IPoolConfigurator.sol";
import { IDataProvider }     from "../src/interfaces/IDataProvider.sol";

import { CapAutomator } from "../src/CapAutomator.sol";

import { MockPoolConfigurator } from "./mocks/MockPoolConfigurator.sol";
import { MockDataProvider }     from "./mocks/MockDataProvider.sol";
import { CapAutomatorHarness }  from "./harnesses/CapAutomatorHarness.sol";

contract CapAutomatorUnitTestBase is Test {

    IPoolConfigurator public configurator;
    IDataProvider     public dataProvider;

    address public owner;
    address public authority;

    CapAutomator public capAutomator;

    function setUp() public {
        configurator = new MockPoolConfigurator();
        dataProvider = new MockDataProvider({
            _aTokenTotalSupply: 6_900_000,
            _totalDebt:         3_900_000,
            _borrowCap:         4_000_000,
            _supplyCap:         7_000_000
        });

        owner        = makeAddr("owner");
        authority    = makeAddr("authority");

        capAutomator = new CapAutomator(configurator, dataProvider);

        capAutomator.setAuthority(authority);
        capAutomator.setOwner(owner);
    }

}

contract ConstructorTests is CapAutomatorUnitTestBase {

    function test_constructor() public {
        capAutomator = new CapAutomator(configurator, dataProvider);

        assertEq(
            address(capAutomator.poolConfigurator()),
            address(configurator)
        );
        assertEq(
            address(capAutomator.dataProvider()),
            address(dataProvider)
        );
        assertEq(
            address(capAutomator.owner()),
            address(this)
        );
    }

}

contract SetOwnerTests is CapAutomatorUnitTestBase {

    function test_setOwner_noAuth() public {
        vm.expectRevert("CapAutomator/only-owner");
        capAutomator.setOwner(makeAddr("newOwner"));
    }

    function test_setOwner() public {
        address newOwner = makeAddr("newOwner");
        assertEq(capAutomator.owner(), owner);

        vm.prank(owner);
        capAutomator.setOwner(newOwner);

        assertEq(capAutomator.owner(), newOwner);
    }

}

contract SetAuthorityTests is CapAutomatorUnitTestBase {

    function test_setAuthority_noAuth() public {
        vm.expectRevert("CapAutomator/only-owner");
        capAutomator.setAuthority(makeAddr("newAuthority"));
    }

    function test_setAuthority() public {
        address newAuthority = makeAddr("newAuthority");
        assertEq(capAutomator.authority(), address(authority));

        vm.prank(owner);
        capAutomator.setAuthority(newAuthority);

        assertEq(capAutomator.authority(), newAuthority);
    }

}

contract SetSupplyCapConfigTests is CapAutomatorUnitTestBase {

    function test_setSupplyCapConfig_noAuth() public {
        vm.expectRevert("CapAutomator/not-authorized");
        capAutomator.setSupplyCapConfig(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            12 hours
        );
    }

    function test_setSupplyCapConfig_invalidCooldown() public {
        vm.expectRevert("CapAutomator/invalid-cooldown");
        vm.prank(authority);
        capAutomator.setSupplyCapConfig(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            2**48
        );
    }

    function test_setSupplyCapConfig_invalidCap() public {
        vm.expectRevert("CapAutomator/invalid-cap");
        vm.prank(authority);
        capAutomator.setSupplyCapConfig(
            makeAddr("asset"),
            0,
            1_000_000,
            12 hours
        );
    }

    function test_setSupplyCapConfig() public {
        (
            uint256 maxCap,
            uint256 capGap,
            uint48  capIncreaseCooldown,
            uint48  lastUpdateBlock,
            uint48  lastIncreaseTime
        ) = capAutomator.supplyCapConfigs(makeAddr("asset"));

        assertEq(maxCap,              0);
        assertEq(capGap,              0);
        assertEq(capIncreaseCooldown, 0);
        assertEq(lastUpdateBlock,     0);
        assertEq(lastIncreaseTime,    0);

        vm.prank(authority);
        capAutomator.setSupplyCapConfig(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            12 hours
        );


        (
            maxCap,
            capGap,
            capIncreaseCooldown,
            lastUpdateBlock,
            lastIncreaseTime
        ) = capAutomator.supplyCapConfigs(makeAddr("asset"));

        assertEq(maxCap,              10_000_000);
        assertEq(capGap,              1_000_000);
        assertEq(capIncreaseCooldown, 12 hours);
        assertEq(lastUpdateBlock,     0);
        assertEq(lastIncreaseTime,    0);
    }

    function test_setSupplyCapConfig_reconfigure() public {
        vm.prank(authority);
        capAutomator.setSupplyCapConfig(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            12 hours
        );

        (
            uint256 maxCap,
            uint256 capGap,
            uint48  capIncreaseCooldown,
            ,
        ) = capAutomator.supplyCapConfigs(makeAddr("asset"));

        assertEq(maxCap,              10_000_000);
        assertEq(capGap,              1_000_000);
        assertEq(capIncreaseCooldown, 12 hours);

        vm.prank(authority);
        capAutomator.setSupplyCapConfig(
            makeAddr("asset"),
            13_000_000,
            1_300_000,
            24 hours
        );

        (
            maxCap,
            capGap,
            capIncreaseCooldown,
            ,
        ) = capAutomator.supplyCapConfigs(makeAddr("asset"));

        assertEq(maxCap,              13_000_000);
        assertEq(capGap,              1_300_000);
        assertEq(capIncreaseCooldown, 24 hours);
    }

    function test_setSupplyCapConfig_preserveUpdateTrackers() public {
        vm.prank(authority);
        capAutomator.setSupplyCapConfig(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            12 hours
        );

        (
            ,,,
            uint48 lastUpdateBlock,
            uint48 lastIncreaseTime
        ) = capAutomator.supplyCapConfigs(makeAddr("asset"));

        assertEq(lastUpdateBlock,  0);
        assertEq(lastIncreaseTime, 0);

        vm.warp(12 hours);
        capAutomator.exec(makeAddr("asset"));

        (
            ,,,
            uint48 postExecUpdateBlock,
            uint48 postExecIncreaseTime
        ) = capAutomator.supplyCapConfigs(makeAddr("asset"));

        assertNotEq(postExecUpdateBlock,  0);
        assertNotEq(postExecIncreaseTime, 0);

        vm.prank(authority);
        capAutomator.setSupplyCapConfig(
            makeAddr("asset"),
            20_000_000,
            2_000_000,
            24 hours
        );

        (
            ,,,
            uint48 postReconfigUpdateBlock,
            uint48 postReconfigIncreaseTime
        ) = capAutomator.supplyCapConfigs(makeAddr("asset"));

        assertEq(postReconfigUpdateBlock,  postExecUpdateBlock);
        assertEq(postReconfigIncreaseTime, postExecIncreaseTime);
    }

}

contract SetBorrowCapConfigTests is CapAutomatorUnitTestBase {

    function test_setBorrowCapConfig_noAuth() public {
        vm.expectRevert("CapAutomator/not-authorized");
        capAutomator.setBorrowCapConfig(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            12 hours
        );
    }

    function test_setBorrowCapConfig_invalidCooldown() public {
        vm.expectRevert("CapAutomator/invalid-cooldown");
        vm.prank(authority);
        capAutomator.setBorrowCapConfig(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            2**48
        );
    }

    function test_setBorrowCapConfig_invalidCap() public {
        vm.expectRevert("CapAutomator/invalid-cap");
        vm.prank(authority);
        capAutomator.setBorrowCapConfig(
            makeAddr("asset"),
            0,
            1_000_000,
            12 hours
        );
    }

    function test_setBorrowCapConfig() public {
        (
            uint256 maxCap,
            uint256 capGap,
            uint48  capIncreaseCooldown,
            uint48  lastUpdateBlock,
            uint48  lastIncreaseTime
        ) = capAutomator.borrowCapConfigs(makeAddr("asset"));

        assertEq(maxCap,              0);
        assertEq(capGap,              0);
        assertEq(capIncreaseCooldown, 0);
        assertEq(lastUpdateBlock,     0);
        assertEq(lastIncreaseTime,    0);

        vm.prank(authority);
        capAutomator.setBorrowCapConfig(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            12 hours
        );

        (
            maxCap,
            capGap,
            capIncreaseCooldown,
            lastUpdateBlock,
            lastIncreaseTime
        ) = capAutomator.borrowCapConfigs(makeAddr("asset"));

        assertEq(maxCap,              10_000_000);
        assertEq(capGap,              1_000_000);
        assertEq(capIncreaseCooldown, 12 hours);
        assertEq(lastUpdateBlock,     0);
        assertEq(lastIncreaseTime,    0);
    }

    function test_setBorrowCapConfig_reconfigure() public {
        vm.prank(authority);
        capAutomator.setBorrowCapConfig(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            12 hours
        );

        (
            uint256 maxCap,
            uint256 capGap,
            uint48  capIncreaseCooldown,
            ,
        ) = capAutomator.borrowCapConfigs(makeAddr("asset"));

        assertEq(maxCap,              10_000_000);
        assertEq(capGap,              1_000_000);
        assertEq(capIncreaseCooldown, 12 hours);

        vm.prank(authority);
        capAutomator.setBorrowCapConfig(
            makeAddr("asset"),
            13_000_000,
            1_300_000,
            24 hours
        );

        (
            maxCap,
            capGap,
            capIncreaseCooldown,
            ,
        ) = capAutomator.borrowCapConfigs(makeAddr("asset"));

        assertEq(maxCap,              13_000_000);
        assertEq(capGap,              1_300_000);
        assertEq(capIncreaseCooldown, 24 hours);
    }

    function test_setBorrowCapConfig_preserveUpdateTrackers() public {
        vm.prank(authority);
        capAutomator.setBorrowCapConfig(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            12 hours
        );

        (
            ,,,
            uint48 lastUpdateBlock,
            uint48 lastIncreaseTime
        ) = capAutomator.borrowCapConfigs(makeAddr("asset"));

        assertEq(lastUpdateBlock,  0);
        assertEq(lastIncreaseTime, 0);

        vm.warp(12 hours);
        capAutomator.exec(makeAddr("asset"));

        (
            ,,,
            uint48 postExecUpdateBlock,
            uint48 postExecIncreaseTime
        ) = capAutomator.borrowCapConfigs(makeAddr("asset"));

        assertNotEq(postExecUpdateBlock,  0);
        assertNotEq(postExecIncreaseTime, 0);

        vm.prank(authority);
        capAutomator.setBorrowCapConfig(
            makeAddr("asset"),
            20_000_000,
            2_000_000,
            24 hours
        );

        (
            ,,,
            uint48 postReconfigUpdateBlock,
            uint48 postReconfigIncreaseTime
        ) = capAutomator.borrowCapConfigs(makeAddr("asset"));

        assertEq(postReconfigUpdateBlock,  postExecUpdateBlock);
        assertEq(postReconfigIncreaseTime, postExecIncreaseTime);
    }

}

contract RemoveSupplyCapConfigTests is CapAutomatorUnitTestBase {

    function test_removeSupplyCapConfig_noAuth() public {
        vm.expectRevert("CapAutomator/not-authorized");
        capAutomator.removeSupplyCapConfig(makeAddr("asset"));
    }

    function test_removeSupplyCapConfig() public {

        vm.prank(authority);
        capAutomator.setSupplyCapConfig(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            12 hours
        );

        (
            uint256 maxCap,
            uint256 capGap,
            uint48  capIncreaseCooldown,
            ,
        ) = capAutomator.supplyCapConfigs(makeAddr("asset"));

        assertEq(maxCap,              10_000_000);
        assertEq(capGap,              1_000_000);
        assertEq(capIncreaseCooldown, 12 hours);

        vm.prank(authority);
        capAutomator.removeSupplyCapConfig(makeAddr("asset"));

        (
            maxCap,
            capGap,
            capIncreaseCooldown,
            ,
        ) = capAutomator.supplyCapConfigs(makeAddr("asset"));

        assertEq(maxCap,              0);
        assertEq(capGap,              0);
        assertEq(capIncreaseCooldown, 0);
    }

}

contract RemoveBorrowCapConfigTests is CapAutomatorUnitTestBase {

    function test_removeBorrowCapConfig_noAuth() public {
        vm.expectRevert("CapAutomator/not-authorized");
        capAutomator.removeBorrowCapConfig(makeAddr("asset"));
    }

    function test_removeBorrowCapConfig() public {

        vm.prank(authority);
        capAutomator.setBorrowCapConfig(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            12 hours
        );

        (
            uint256 maxCap,
            uint256 capGap,
            uint48  capIncreaseCooldown,
            ,
        ) = capAutomator.borrowCapConfigs(makeAddr("asset"));

        assertEq(maxCap,              10_000_000);
        assertEq(capGap,              1_000_000);
        assertEq(capIncreaseCooldown, 12 hours);

        vm.prank(authority);
        capAutomator.removeBorrowCapConfig(makeAddr("asset"));

        (
            maxCap,
            capGap,
            capIncreaseCooldown,
            ,
        ) = capAutomator.borrowCapConfigs(makeAddr("asset"));

        assertEq(maxCap,              0);
        assertEq(capGap,              0);
        assertEq(capIncreaseCooldown, 0);
    }

}

contract CalculateNewCapTests is Test {

    IPoolConfigurator public configurator;
    IDataProvider     public dataProvider;

    address public owner;
    address public authority;

    CapAutomator public capAutomator;

    function setUp() public {
        configurator = new MockPoolConfigurator();
        dataProvider = new MockDataProvider({
            _aTokenTotalSupply: 6_900_000,
            _totalDebt:         3_900_000,
            _borrowCap:         4_000_000,
            _supplyCap:         7_000_000
        });

        owner        = makeAddr("owner");
        authority    = makeAddr("authority");

        capAutomator = new CapAutomatorHarness(configurator, dataProvider);

        capAutomator.setAuthority(authority);
        capAutomator.setOwner(owner);
    }

    function test_calculateNewCap() public {
        // TODO: Test that in a simple, happy path scenario, everything is set properly
    }

    function test_calculateNewCap_notConfigured() public {
        // TODO: if there is no configuration for the updated market, return current supply cap
    }

    function test_calculateNewCap_sameBlock() public {
        // TODO: if there is an attempt to update twice in the same block, return current supply cap
    }

    function test_calculateNewCap_sameCap() public {
        // TODO: if new cap is the same as current cap, return current supply cap
    }

    function test_calculateNewCap_closeToMaxCap() public {
        // TODO: if it's not possible to increase the full gap, increase to the max amount
    }

    function test_calculateNewCap_aboveMaxCap() public {
        // TODO: if if the current cap is above max cap, decrease to the max amount
    }

    function test_calculateNewCap_cooldown() public {
        // TODO: if there is a second attempt to increase the cap before the cooldown passes, allow only decreases (allow another increase after cooldown passes)
    }
}

contract UpdateSupplyCapConfigTests is Test {

    IPoolConfigurator public configurator;
    IDataProvider     public dataProvider;

    address public owner;
    address public authority;

    CapAutomator public capAutomator;

    function setUp() public {
        configurator = new MockPoolConfigurator();
        dataProvider = new MockDataProvider({
            _aTokenTotalSupply: 6_900_000,
            _totalDebt:         3_900_000,
            _borrowCap:         4_000_000,
            _supplyCap:         7_000_000
        });

        owner        = makeAddr("owner");
        authority    = makeAddr("authority");

        capAutomator = new CapAutomatorHarness(configurator, dataProvider);

        capAutomator.setAuthority(authority);
        capAutomator.setOwner(owner);
    }

    function test_updateSupplyCapConfig() public {
        // TODO: Test that in a simple, happy path scenario, everything is set properly
    }
    function test_updateSupplyCapConfig_sameCap() public {
        // TODO: if for any reason cap should not be updated, return current supply cap
    }
    function test_updateSupplyCapConfig_cooldown() public {
        // TODO: check if update trackers are updated properly on increase and decrease
    }

}

contract UpdateBorrowCapConfigTests is Test {

    IPoolConfigurator public configurator;
    IDataProvider     public dataProvider;

    address public owner;
    address public authority;

    CapAutomator public capAutomator;

    function setUp() public {
        configurator = new MockPoolConfigurator();
        dataProvider = new MockDataProvider({
            _aTokenTotalSupply: 6_900_000,
            _totalDebt:         3_900_000,
            _borrowCap:         4_000_000,
            _supplyCap:         7_000_000
        });

        owner        = makeAddr("owner");
        authority    = makeAddr("authority");

        capAutomator = new CapAutomatorHarness(configurator, dataProvider);

        capAutomator.setAuthority(authority);
        capAutomator.setOwner(owner);
    }

    function test_updateBorrowCapConfig() public {
        // TODO: Test that in a simple, happy path scenario, everything is set properly
    }
    function test_updateBorrowCapConfig_sameCap() public {
        // TODO: if for any reason cap should not be updated, return current supply cap
    }
    function test_updateBorrowCapConfig_cooldown() public {
        // TODO: check if update trackers are updated properly on increase and decrease
    }

}

contract ExecTests is CapAutomatorUnitTestBase {

    function test_exec() public {
        // TODO Happy path end to end test of update of both borrow and supply cap (still on mocks though)
    }

}
