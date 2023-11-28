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

    MockPoolConfigurator public configurator;
    MockDataProvider     public dataProvider;

    address public owner;
    address public authority;
    address public asset;

    CapAutomator public capAutomator;

    function setUp() public {
        configurator = new MockPoolConfigurator();
        dataProvider = new MockDataProvider({
            _aTokenTotalSupply: 6_900_000,
            _totalDebt:         3_900_000,
            _borrowCap:         4_000_000,
            _supplyCap:         7_000_000
        });

        owner     = makeAddr("owner");
        authority = makeAddr("authority");
        asset     = makeAddr("asset");

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
            asset,
            10_000_000,
            1_000_000,
            12 hours
        );
    }

    function test_setSupplyCapConfig_invalidCooldown() public {
        vm.expectRevert("CapAutomator/invalid-cooldown");
        vm.prank(authority);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000_000,
            1_000_000,
            2**48
        );
    }

    function test_setSupplyCapConfig_invalidCap() public {
        vm.expectRevert("CapAutomator/invalid-cap");
        vm.prank(authority);
        capAutomator.setSupplyCapConfig(
            asset,
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
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(maxCap,              0);
        assertEq(capGap,              0);
        assertEq(capIncreaseCooldown, 0);
        assertEq(lastUpdateBlock,     0);
        assertEq(lastIncreaseTime,    0);

        vm.prank(authority);
        capAutomator.setSupplyCapConfig(
            asset,
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
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(maxCap,              10_000_000);
        assertEq(capGap,              1_000_000);
        assertEq(capIncreaseCooldown, 12 hours);
        assertEq(lastUpdateBlock,     0);
        assertEq(lastIncreaseTime,    0);
    }

    function test_setSupplyCapConfig_reconfigure() public {
        vm.prank(authority);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000_000,
            1_000_000,
            12 hours
        );

        (
            uint256 maxCap,
            uint256 capGap,
            uint48  capIncreaseCooldown,
            ,
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(maxCap,              10_000_000);
        assertEq(capGap,              1_000_000);
        assertEq(capIncreaseCooldown, 12 hours);

        vm.prank(authority);
        capAutomator.setSupplyCapConfig(
            asset,
            13_000_000,
            1_300_000,
            24 hours
        );

        (
            maxCap,
            capGap,
            capIncreaseCooldown,
            ,
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(maxCap,              13_000_000);
        assertEq(capGap,              1_300_000);
        assertEq(capIncreaseCooldown, 24 hours);
    }

    function test_setSupplyCapConfig_preserveUpdateTrackers() public {
        vm.prank(authority);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000_000,
            1_000_000,
            12 hours
        );

        (
            ,,,
            uint48 lastUpdateBlock,
            uint48 lastIncreaseTime
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(lastUpdateBlock,  0);
        assertEq(lastIncreaseTime, 0);

        vm.warp(12 hours);
        capAutomator.exec(asset);

        (
            ,,,
            uint48 postExecUpdateBlock,
            uint48 postExecIncreaseTime
        ) = capAutomator.supplyCapConfigs(asset);

        assertNotEq(postExecUpdateBlock,  0);
        assertNotEq(postExecIncreaseTime, 0);

        vm.prank(authority);
        capAutomator.setSupplyCapConfig(
            asset,
            20_000_000,
            2_000_000,
            24 hours
        );

        (
            ,,,
            uint48 postReconfigUpdateBlock,
            uint48 postReconfigIncreaseTime
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(postReconfigUpdateBlock,  postExecUpdateBlock);
        assertEq(postReconfigIncreaseTime, postExecIncreaseTime);
    }

}

contract SetBorrowCapConfigTests is CapAutomatorUnitTestBase {

    function test_setBorrowCapConfig_noAuth() public {
        vm.expectRevert("CapAutomator/not-authorized");
        capAutomator.setBorrowCapConfig(
            asset,
            10_000_000,
            1_000_000,
            12 hours
        );
    }

    function test_setBorrowCapConfig_invalidCooldown() public {
        vm.expectRevert("CapAutomator/invalid-cooldown");
        vm.prank(authority);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000_000,
            1_000_000,
            2**48
        );
    }

    function test_setBorrowCapConfig_invalidCap() public {
        vm.expectRevert("CapAutomator/invalid-cap");
        vm.prank(authority);
        capAutomator.setBorrowCapConfig(
            asset,
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
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(maxCap,              0);
        assertEq(capGap,              0);
        assertEq(capIncreaseCooldown, 0);
        assertEq(lastUpdateBlock,     0);
        assertEq(lastIncreaseTime,    0);

        vm.prank(authority);
        capAutomator.setBorrowCapConfig(
            asset,
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
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(maxCap,              10_000_000);
        assertEq(capGap,              1_000_000);
        assertEq(capIncreaseCooldown, 12 hours);
        assertEq(lastUpdateBlock,     0);
        assertEq(lastIncreaseTime,    0);
    }

    function test_setBorrowCapConfig_reconfigure() public {
        vm.prank(authority);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000_000,
            1_000_000,
            12 hours
        );

        (
            uint256 maxCap,
            uint256 capGap,
            uint48  capIncreaseCooldown,
            ,
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(maxCap,              10_000_000);
        assertEq(capGap,              1_000_000);
        assertEq(capIncreaseCooldown, 12 hours);

        vm.prank(authority);
        capAutomator.setBorrowCapConfig(
            asset,
            13_000_000,
            1_300_000,
            24 hours
        );

        (
            maxCap,
            capGap,
            capIncreaseCooldown,
            ,
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(maxCap,              13_000_000);
        assertEq(capGap,              1_300_000);
        assertEq(capIncreaseCooldown, 24 hours);
    }

    function test_setBorrowCapConfig_preserveUpdateTrackers() public {
        vm.prank(authority);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000_000,
            1_000_000,
            12 hours
        );

        (
            ,,,
            uint48 lastUpdateBlock,
            uint48 lastIncreaseTime
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(lastUpdateBlock,  0);
        assertEq(lastIncreaseTime, 0);

        vm.warp(12 hours);
        capAutomator.exec(asset);

        (
            ,,,
            uint48 postExecUpdateBlock,
            uint48 postExecIncreaseTime
        ) = capAutomator.borrowCapConfigs(asset);

        assertNotEq(postExecUpdateBlock,  0);
        assertNotEq(postExecIncreaseTime, 0);

        vm.prank(authority);
        capAutomator.setBorrowCapConfig(
            asset,
            20_000_000,
            2_000_000,
            24 hours
        );

        (
            ,,,
            uint48 postReconfigUpdateBlock,
            uint48 postReconfigIncreaseTime
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(postReconfigUpdateBlock,  postExecUpdateBlock);
        assertEq(postReconfigIncreaseTime, postExecIncreaseTime);
    }

}

contract RemoveSupplyCapConfigTests is CapAutomatorUnitTestBase {

    function test_removeSupplyCapConfig_noAuth() public {
        vm.expectRevert("CapAutomator/not-authorized");
        capAutomator.removeSupplyCapConfig(asset);
    }

    function test_removeSupplyCapConfig() public {

        vm.prank(authority);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000_000,
            1_000_000,
            12 hours
        );

        (
            uint256 maxCap,
            uint256 capGap,
            uint48  capIncreaseCooldown,
            ,
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(maxCap,              10_000_000);
        assertEq(capGap,              1_000_000);
        assertEq(capIncreaseCooldown, 12 hours);

        vm.prank(authority);
        capAutomator.removeSupplyCapConfig(asset);

        (
            maxCap,
            capGap,
            capIncreaseCooldown,
            ,
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(maxCap,              0);
        assertEq(capGap,              0);
        assertEq(capIncreaseCooldown, 0);
    }

}

contract RemoveBorrowCapConfigTests is CapAutomatorUnitTestBase {

    function test_removeBorrowCapConfig_noAuth() public {
        vm.expectRevert("CapAutomator/not-authorized");
        capAutomator.removeBorrowCapConfig(asset);
    }

    function test_removeBorrowCapConfig() public {

        vm.prank(authority);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000_000,
            1_000_000,
            12 hours
        );

        (
            uint256 maxCap,
            uint256 capGap,
            uint48  capIncreaseCooldown,
            ,
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(maxCap,              10_000_000);
        assertEq(capGap,              1_000_000);
        assertEq(capIncreaseCooldown, 12 hours);

        vm.prank(authority);
        capAutomator.removeBorrowCapConfig(asset);

        (
            maxCap,
            capGap,
            capIncreaseCooldown,
            ,
        ) = capAutomator.borrowCapConfigs(asset);

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

    CapAutomatorHarness public capAutomator;

    function setUp() public {
        configurator = new MockPoolConfigurator();
        dataProvider = new MockDataProvider(0, 0, 0, 0);

        owner     = makeAddr("owner");
        authority = makeAddr("authority");

        capAutomator = new CapAutomatorHarness(configurator, dataProvider);

        capAutomator.setAuthority(authority);
        capAutomator.setOwner(owner);
    }

    function test_calculateNewCap() public {
        uint256 newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                maxCap: 5_000_000,
                capGap: 500_000,
                capIncreaseCooldown: 0,
                lastUpdateBlock: 0,
                lastIncreaseTime: 0
            }),
            1_900_000,
            2_000_000
        );
        assertEq(newCap, 2_400_000);
    }

    function test_calculateNewCap_notConfigured() public {
        uint256 newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                maxCap: 0,
                capGap: 0,
                capIncreaseCooldown: 0,
                lastUpdateBlock: 0,
                lastIncreaseTime: 0
            }),
            1_900_000,
            2_000_000
        );
        assertEq(newCap, 2_000_000);
    }

    function test_calculateNewCap_sameBlock() public {
        vm.roll(100);
        uint256 newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                maxCap: 5_000_000,
                capGap: 500_000,
                capIncreaseCooldown: 0,
                lastUpdateBlock: 99,
                lastIncreaseTime: 0
            }),
            1_900_000,
            2_000_000
        );
        assertEq(newCap, 2_400_000);

        newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                maxCap: 5_000_000,
                capGap: 500_000,
                capIncreaseCooldown: 0,
                lastUpdateBlock: 100,
                lastIncreaseTime: 0
            }),
            1_900_000,
            2_000_000
        );
        assertEq(newCap, 2_000_000);
    }

    function test_calculateNewCap_sameCap() public {
        uint256 newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                maxCap: 5_000_000,
                capGap: 500_000,
                capIncreaseCooldown: 0,
                lastUpdateBlock: 0,
                lastIncreaseTime: 0
            }),
            1_500_000,
            2_000_000
        );
        assertEq(newCap, 2_000_000);
    }

    function test_calculateNewCap_closeToMaxCap() public {
        uint256 newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                maxCap: 5_000_000,
                capGap: 500_000,
                capIncreaseCooldown: 0,
                lastUpdateBlock: 0,
                lastIncreaseTime: 0
            }),
            4_800_000,
            4_900_000
        );
        assertEq(newCap, 5_000_000);
    }

    function test_calculateNewCap_aboveMaxCap() public {
        uint256 newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                maxCap: 5_000_000,
                capGap: 500_000,
                capIncreaseCooldown: 0,
                lastUpdateBlock: 0,
                lastIncreaseTime: 0
            }),
            4_800_000,
            5_200_000
        );
        assertEq(newCap, 5_000_000);
    }

    function test_calculateNewCap_cooldown() public {
        vm.warp(12 hours);
        uint256 newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                maxCap: 5_000_000,
                capGap: 500_000,
                capIncreaseCooldown: 12 hours,
                lastUpdateBlock: 0,
                lastIncreaseTime: 12 hours
            }),
            1_900_000,
            2_000_000
        );
        assertEq(newCap, 2_000_000);

        newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                maxCap: 5_000_000,
                capGap: 500_000,
                capIncreaseCooldown: 12 hours,
                lastUpdateBlock: 0,
                lastIncreaseTime: 12 hours
            }),
            1_200_000,
            2_000_000
        );
        assertEq(newCap, 1_700_000);

        vm.warp(24 hours);
        newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                maxCap: 5_000_000,
                capGap: 500_000,
                capIncreaseCooldown: 12 hours,
                lastUpdateBlock: 0,
                lastIncreaseTime: 12 hours
            }),
            1_900_000,
            2_000_000
        );
        assertEq(newCap, 2_400_000);
    }

}

contract UpdateSupplyCapConfigTests is Test {

    MockPoolConfigurator public configurator;
    MockDataProvider     public dataProvider;

    address public owner;
    address public authority;
    address public asset;

    CapAutomatorHarness public capAutomator;

    function setUp() public {
        owner     = makeAddr("owner");
        authority = makeAddr("authority");
        asset     = makeAddr("asset");

        configurator = new MockPoolConfigurator();
        dataProvider = new MockDataProvider({
            _aTokenTotalSupply: 6_900_000,
            _totalDebt:         3_900_000,
            _borrowCap:         4_000_000,
            _supplyCap:         7_000_000
        });
        configurator.setSupplyCap(asset, 7_000_000);

        capAutomator = new CapAutomatorHarness(configurator, dataProvider);

        capAutomator.setAuthority(authority);
        capAutomator.setOwner(owner);
    }

    function test_updateSupplyCapConfig() public {
        vm.roll(100);
        vm.warp(100_000);

        vm.prank(authority);
        capAutomator.setSupplyCapConfig({
            asset: asset,
            maxCap: 10_000_000,
            capGap: 500_000,
            capIncreaseCooldown: 0
        });

        assertEq(configurator.supplyCap(asset), 7_000_000);

        (,,,uint48 lastUpdateBlockBefore, uint48 lastIncreaseTimeBefore) = capAutomator.supplyCapConfigs(asset);
        assertEq(lastUpdateBlockBefore,  0);
        assertEq(lastIncreaseTimeBefore, 0);

        vm.expectCall(address(configurator), abi.encodeCall(IPoolConfigurator.setSupplyCap, (asset, uint256(7_400_000))), 1);
        assertEq(capAutomator._updateSupplyCapConfigExternal(asset), 7_400_000);

        assertEq(configurator.supplyCap(asset), 7_400_000);

        (,,,uint48 lastUpdateBlockAfter, uint48 lastIncreaseTimeAfter) = capAutomator.supplyCapConfigs(asset);
        assertEq(lastUpdateBlockAfter,  100);
        assertEq(lastIncreaseTimeAfter, 100_000);
    }

    function test_updateSupplyCapConfig_sameCap() public {
        vm.prank(authority);
        capAutomator.setSupplyCapConfig({
            asset: asset,
            maxCap: 10_000_000,
            capGap: 100_000,
            capIncreaseCooldown: 0
        });

        assertEq(configurator.supplyCap(asset), 7_000_000);

        vm.expectCall(address(configurator), abi.encodeCall(IPoolConfigurator.setSupplyCap, (asset, uint256(7_000_000))), 0);
        assertEq(capAutomator._updateSupplyCapConfigExternal(asset), 7_000_000);

        assertEq(configurator.supplyCap(asset), 7_000_000);
    }

}

contract UpdateBorrowCapConfigTests is Test {

    MockPoolConfigurator public configurator;
    MockDataProvider     public dataProvider;

    address public owner;
    address public authority;
    address public asset;

    CapAutomatorHarness public capAutomator;

    function setUp() public {
        owner     = makeAddr("owner");
        authority = makeAddr("authority");
        asset     = makeAddr("asset");

        configurator = new MockPoolConfigurator();
        dataProvider = new MockDataProvider({
            _aTokenTotalSupply: 6_900_000,
            _totalDebt:         3_900_000,
            _borrowCap:         4_000_000,
            _supplyCap:         7_000_000
        });
        configurator.setBorrowCap(asset, 4_000_000);

        capAutomator = new CapAutomatorHarness(configurator, dataProvider);

        capAutomator.setAuthority(authority);
        capAutomator.setOwner(owner);
    }

    function test_updateBorrowCapConfig() public {
        vm.roll(100);
        vm.warp(100_000);

        vm.prank(authority);
        capAutomator.setBorrowCapConfig({
            asset:               asset,
            maxCap:              10_000_000,
            capGap:              500_000,
            capIncreaseCooldown: 0
        });

        assertEq(configurator.borrowCap(asset), 4_000_000);

        (,,,uint48 lastUpdateBlockBefore, uint48 lastIncreaseTimeBefore) = capAutomator.borrowCapConfigs(asset);
        assertEq(lastUpdateBlockBefore,  0);
        assertEq(lastIncreaseTimeBefore, 0);

        vm.expectCall(address(configurator), abi.encodeCall(IPoolConfigurator.setBorrowCap, (asset, uint256(4_400_000))), 1);
        assertEq(capAutomator._updateBorrowCapConfigExternal(asset), 4_400_000);

        assertEq(configurator.borrowCap(asset), 4_400_000);

        (,,,uint48 lastUpdateBlockAfter, uint48 lastIncreaseTimeAfter) = capAutomator.borrowCapConfigs(asset);
        assertEq(lastUpdateBlockAfter,  100);
        assertEq(lastIncreaseTimeAfter, 100_000);
    }

    function test_updateBorrowCapConfig_sameCap() public {
        vm.prank(authority);
        capAutomator.setBorrowCapConfig({
            asset:               asset,
            maxCap:              10_000_000,
            capGap:              100_000,
            capIncreaseCooldown: 0
        });

        assertEq(configurator.borrowCap(asset), 4_000_000);

        vm.expectCall(address(configurator), abi.encodeCall(IPoolConfigurator.setBorrowCap, (asset, uint256(4_000_000))), 0);
        assertEq(capAutomator._updateBorrowCapConfigExternal(asset), 4_000_000);

        assertEq(configurator.borrowCap(asset), 4_000_000);
    }

}

contract ExecTests is CapAutomatorUnitTestBase {

    function test_exec() public {
        configurator.setSupplyCap(asset, 7_000_000);
        configurator.setBorrowCap(asset, 4_000_000);

        vm.roll(100);
        vm.warp(100_000);

        vm.startPrank(authority);
        capAutomator.setSupplyCapConfig({
            asset:               asset,
            maxCap:              10_000_000,
            capGap:              400_000,
            capIncreaseCooldown: 0
        });
        capAutomator.setBorrowCapConfig({
            asset:               asset,
            maxCap:              8_000_000,
            capGap:              300_000,
            capIncreaseCooldown: 0
        });
        vm.stopPrank();

        assertEq(configurator.supplyCap(asset), 7_000_000);
        assertEq(configurator.borrowCap(asset), 4_000_000);

        vm.expectCall(address(configurator), abi.encodeCall(IPoolConfigurator.setSupplyCap, (asset, uint256(7_300_000))), 1);
        vm.expectCall(address(configurator), abi.encodeCall(IPoolConfigurator.setBorrowCap, (asset, uint256(4_200_000))), 1);

        (uint256 newSupplyCap, uint256 newBorrowCap) = capAutomator.exec(asset);

        assertEq(newSupplyCap, 7_300_000);
        assertEq(newBorrowCap, 4_200_000);

        assertEq(configurator.supplyCap(asset), 7_300_000);
        assertEq(configurator.borrowCap(asset), 4_200_000);
    }

}

contract EventTests is CapAutomatorUnitTestBase {
    event SetOwner(address indexed oldOwner, address indexed newOwner);
    event SetAuthority(address indexed oldAuthority, address indexed newAuthority);

    event SetSupplyCapConfig(address indexed asset, uint256 maxCap, uint256 capGap, uint256 capIncreaseCooldown);
    event SetBorrowCapConfig(address indexed asset, uint256 maxCap, uint256 capGap, uint256 capIncreaseCooldown);

    event RemoveSupplyCapConfig(address indexed asset);
    event RemoveBorrowCapConfig(address indexed asset);

    event UpdateSupplyCap(address indexed asset, uint256 oldSupplyCap, uint256 newSupplyCap);
    event UpdateBorrowCap(address indexed asset, uint256 oldBorrowCap, uint256 newBorrowCap);

    function test_SetOwner() public {
        address newOwner = makeAddr("newOwner");
        vm.prank(owner);
        vm.expectEmit(address(capAutomator));
        emit SetOwner(owner, newOwner);
        capAutomator.setOwner(newOwner);
    }

    function test_SetAuthority() public {
        address newAuthority = makeAddr("newAuthority");
        vm.prank(owner);
        vm.expectEmit(address(capAutomator));
        emit SetAuthority(authority, newAuthority);
        capAutomator.setAuthority(newAuthority);
    }

    function test_SetSupplyCapConfig() public {
        vm.prank(authority);
        vm.expectEmit(address(capAutomator));
        emit SetSupplyCapConfig(
            asset,
            20_000_000,
            2_000_000,
            24 hours
        );
        capAutomator.setSupplyCapConfig(
            asset,
            20_000_000,
            2_000_000,
            24 hours
        );
    }

    function test_SetBorrowCapConfig() public {
        vm.prank(authority);
        vm.expectEmit(address(capAutomator));
        emit SetBorrowCapConfig(
            asset,
            10_000_000,
            1_000_000,
            12 hours
        );
        capAutomator.setBorrowCapConfig(
            asset,
            10_000_000,
            1_000_000,
            12 hours
        );
    }

    function test_RemoveSupplyCapConfig() public {
        vm.prank(authority);
        vm.expectEmit(address(capAutomator));
        emit RemoveSupplyCapConfig(asset);
        capAutomator.removeSupplyCapConfig(asset);
    }

    function test_RemoveBorrowCapConfig() public {
        vm.prank(authority);
        vm.expectEmit(address(capAutomator));
        emit RemoveBorrowCapConfig(asset);
        capAutomator.removeBorrowCapConfig(asset);
    }

    function test_UpdateSupplyCap() public {
        vm.prank(authority);
        capAutomator.setSupplyCapConfig({
            asset:               asset,
            maxCap:              10_000_000,
            capGap:              400_000,
            capIncreaseCooldown: 0
        });

        vm.expectEmit(address(capAutomator));
        emit UpdateSupplyCap(asset, 7_000_000, 7_300_000);
        capAutomator.exec(asset);
    }

    function test_UpdateBorrowCap() public {
        vm.prank(authority);
        capAutomator.setBorrowCapConfig({
            asset:               asset,
            maxCap:              8_000_000,
            capGap:              300_000,
            capIncreaseCooldown: 0
        });

        vm.expectEmit(address(capAutomator));
        emit UpdateBorrowCap(asset, 4_000_000, 4_200_000);
        capAutomator.exec(asset);
    }

}
