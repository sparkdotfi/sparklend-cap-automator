// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { IAccessControl }           from "openzeppelin-contracts/access/IAccessControl.sol";
import { IAccessControlEnumerable } from "openzeppelin-contracts/access/extensions/IAccessControlEnumerable.sol";

import { ReserveConfiguration } from "aave-v3-core-contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import { DataTypes }            from "aave-v3-core-contracts/protocol/libraries/types/DataTypes.sol";
import { IPool }                from "aave-v3-core-contracts/interfaces/IPool.sol";
import { IPoolConfigurator }    from "aave-v3-core-contracts/interfaces/IPoolConfigurator.sol";

import { MockPoolAddressesProvider } from "./mocks/MockPoolAddressesProvider.sol";
import { MockPoolConfigurator }      from "./mocks/MockPoolConfigurator.sol";
import { MockPool }                  from "./mocks/MockPool.sol";
import { CapAutomatorHarness }       from "./harnesses/CapAutomatorHarness.sol";

import { CapAutomator } from "../src/CapAutomator.sol";

contract CapAutomatorUnitTestBase is Test {

    MockPoolAddressesProvider public mockPoolAddressesProvider;
    MockPool                  public mockPool;
    MockPoolConfigurator      public mockPoolConfigurator;

    address public admin;
    address public updater1;
    address public updater2;
    address public asset;

    CapAutomator public capAutomator;

    bytes32 public DEFAULT_ADMIN_ROLE;
    bytes32 public UPDATE_ROLE;

    function setUp() public {
        admin = makeAddr("admin");
        asset = makeAddr("asset");

        updater1 = makeAddr("updater-1");
        updater2 = makeAddr("updater-2");

        mockPool                  = new MockPool();
        mockPoolConfigurator      = new MockPoolConfigurator(mockPool);
        mockPoolAddressesProvider = new MockPoolAddressesProvider(
            address(mockPool),
            address(mockPoolConfigurator)
        );

        mockPool.__setSupplyCap(7_000);

        mockPool.aToken().__setDecimals(18);
        mockPool.__setATokenScaledTotalSupply(5_700e18);
        mockPool.__setAccruedToTreasury(50e18);
        mockPool.__setLiquidityIndex(1.2e27);
        // (aToken. scaledTotalSupply + accruedToTreasury) * liquidityIndex = 6_900e18

        mockPool.__setBorrowCap(4_000);

        mockPool.debtToken().__setDecimals(18);
        mockPool.__setTotalDebt(3_900e18);

        capAutomator = new CapAutomator(
            address(mockPoolAddressesProvider),
            admin,
            updater1
        );

        DEFAULT_ADMIN_ROLE = capAutomator.DEFAULT_ADMIN_ROLE();
        UPDATE_ROLE        = capAutomator.UPDATE_ROLE();

        vm.prank(admin);
        capAutomator.grantRole(UPDATE_ROLE, updater2);
    }

}

contract ConstructorTests is CapAutomatorUnitTestBase {

    function test_constructor_setsInitialState() public {
        assertEq(address(capAutomator.pool()),             address(mockPool));
        assertEq(address(capAutomator.poolConfigurator()), address(mockPoolConfigurator));

        assertEq(capAutomator.hasRole(DEFAULT_ADMIN_ROLE, admin),    true);
        assertEq(capAutomator.hasRole(UPDATE_ROLE,        updater1), true);
        assertEq(capAutomator.hasRole(UPDATE_ROLE,        updater2), true);
    }

    function test_constructor_zeroAddress() public {
        vm.expectRevert("CapAutomator/invalid-admin-address");
        new CapAutomator(address(mockPoolAddressesProvider), address(0), updater1);

        vm.expectRevert("CapAutomator/invalid-updater-address");
        new CapAutomator(address(mockPoolAddressesProvider), admin, address(0));
    }

}

contract GrantRoleTests is CapAutomatorUnitTestBase {

    function test_grantRole_defaultAdminRole_noAuth() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                DEFAULT_ADMIN_ROLE
            )
        );
        capAutomator.grantRole(DEFAULT_ADMIN_ROLE, makeAddr("newAdmin"));
    }

    function test_grantRole_grantsDefaultAdmin() public {
        address newAdmin = makeAddr("newAdmin");

        assertEq(capAutomator.hasRole(DEFAULT_ADMIN_ROLE, newAdmin), false);

        vm.prank(admin);
        capAutomator.grantRole(DEFAULT_ADMIN_ROLE, newAdmin);

        assertEq(capAutomator.hasRole(DEFAULT_ADMIN_ROLE, newAdmin), true);
    }

    function test_grantRole_updateRole_noAuth() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                DEFAULT_ADMIN_ROLE
            )
        );
        capAutomator.grantRole(UPDATE_ROLE, makeAddr("newUpdater"));
    }

    function test_grantRole_updateRole() public {
        address newUpdater = makeAddr("newUpdater");

        assertEq(capAutomator.hasRole(UPDATE_ROLE, newUpdater), false);

        vm.prank(admin);
        capAutomator.grantRole(UPDATE_ROLE, newUpdater);

        assertEq(capAutomator.hasRole(UPDATE_ROLE, newUpdater), true);
    }

}

contract RenounceRoleTests is CapAutomatorUnitTestBase {

    function test_renounceAdminRole_noAuth() public {
        vm.expectRevert(IAccessControl.AccessControlBadConfirmation.selector);
        capAutomator.renounceRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function test_renounceAdminRole() public {
        assertEq(capAutomator.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        vm.prank(admin);
        capAutomator.renounceRole(DEFAULT_ADMIN_ROLE, admin);

        assertEq(capAutomator.hasRole(DEFAULT_ADMIN_ROLE, admin), false);
    }

    function test_renounceUpdateRole_noAuth() public {
        vm.expectRevert(IAccessControl.AccessControlBadConfirmation.selector); 
        capAutomator.renounceRole(UPDATE_ROLE, updater1);
    }

    function test_renounceUpdateRole() public {
        assertEq(capAutomator.hasRole(UPDATE_ROLE, updater1), true);

        vm.prank(updater1);
        capAutomator.renounceRole(UPDATE_ROLE, updater1);

        assertEq(capAutomator.hasRole(UPDATE_ROLE, updater1), false);
    }

}

contract RevokeRoleTests is CapAutomatorUnitTestBase {

    function test_revokeAdminRole_noAuth() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                DEFAULT_ADMIN_ROLE
            )
        );
        capAutomator.revokeRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function test_revokeAdminRole() public {
        address newAdmin = makeAddr("newAdmin");

        vm.prank(admin);
        capAutomator.grantRole(DEFAULT_ADMIN_ROLE, newAdmin);

        assertEq(capAutomator.hasRole(DEFAULT_ADMIN_ROLE, newAdmin), true);

        vm.prank(admin);
        capAutomator.revokeRole(DEFAULT_ADMIN_ROLE, newAdmin);

        assertEq(capAutomator.hasRole(DEFAULT_ADMIN_ROLE, newAdmin), false);

        vm.prank(admin);
        capAutomator.revokeRole(DEFAULT_ADMIN_ROLE, admin);

        assertEq(capAutomator.hasRole(DEFAULT_ADMIN_ROLE, admin), false);
    }

    function test_revokeUpdateRole_noAuth() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                DEFAULT_ADMIN_ROLE
            )
        );
        capAutomator.revokeRole(UPDATE_ROLE, updater1);

        // Self revoking role
        vm.prank(updater1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                updater1,
                DEFAULT_ADMIN_ROLE
            )
        );
        capAutomator.revokeRole(UPDATE_ROLE, updater1);
    }

    function test_revokeUpdateRole() public {
        assertEq(capAutomator.hasRole(UPDATE_ROLE, updater1), true);

        vm.prank(admin);
        capAutomator.revokeRole(UPDATE_ROLE, updater1);

        assertEq(capAutomator.hasRole(UPDATE_ROLE, updater1), false);
    }

}

contract GetRoleAdminTests is CapAutomatorUnitTestBase {

    function test_getRoleAdmin_defaultAdminRole() public {
        assertEq(capAutomator.getRoleAdmin(DEFAULT_ADMIN_ROLE), DEFAULT_ADMIN_ROLE);
    }

    function test_getRoleAdmin_updateRole() public {
        assertEq(capAutomator.getRoleAdmin(UPDATE_ROLE), DEFAULT_ADMIN_ROLE);
    }
}

contract AccessControlEnumerableRolesTests is CapAutomatorUnitTestBase {

    function test_getRoleMemberCount_defaultAdminRole() public {
        assertEq(capAutomator.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);
    }

    function test_getRoleMemberCount_updateRole() public {
        assertEq(capAutomator.getRoleMemberCount(UPDATE_ROLE), 2);
    }

    function test_getRoleMember_defaultAdminRole() public {
        assertEq(capAutomator.getRoleMember(DEFAULT_ADMIN_ROLE, 0), admin);
    }

    function test_getRoleMember_updateRole() public {
        assertEq(capAutomator.getRoleMember(UPDATE_ROLE, 0), updater1);
        assertEq(capAutomator.getRoleMember(UPDATE_ROLE, 1), updater2);
    }

    function test_getRoleMemberCount_afterGrant() public {
        address newAdmin = makeAddr("newAdmin");

        assertEq(capAutomator.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);

        vm.prank(admin);
        capAutomator.grantRole(DEFAULT_ADMIN_ROLE, newAdmin);

        assertEq(capAutomator.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 2);
        assertEq(capAutomator.getRoleMember(DEFAULT_ADMIN_ROLE, 1),   newAdmin);

        address newUpdater = makeAddr("newUpdater");

        assertEq(capAutomator.getRoleMemberCount(UPDATE_ROLE), 2);

        vm.prank(admin);
        capAutomator.grantRole(UPDATE_ROLE, newUpdater);

        assertEq(capAutomator.getRoleMemberCount(UPDATE_ROLE), 3);
        assertEq(capAutomator.getRoleMember(UPDATE_ROLE, 2),   newUpdater);
    }

    function test_getRoleMemberCount_afterRevoke() public {
        // Test revoking UPDATE_ROLE first (while admin still has permissions)
        assertEq(capAutomator.getRoleMemberCount(UPDATE_ROLE), 2);

        vm.prank(admin);
        capAutomator.revokeRole(UPDATE_ROLE, updater1);

        assertEq(capAutomator.getRoleMemberCount(UPDATE_ROLE), 1);
        assertEq(capAutomator.getRoleMember(UPDATE_ROLE, 0),   updater2);

        // Test revoking DEFAULT_ADMIN_ROLE
        assertEq(capAutomator.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);

        vm.prank(admin);
        capAutomator.revokeRole(DEFAULT_ADMIN_ROLE, admin);

        assertEq(capAutomator.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 0);
    }

    function test_getRoleMemberCount_afterRenounce() public {
        // Test renouncing UPDATE_ROLE
        assertEq(capAutomator.getRoleMemberCount(UPDATE_ROLE), 2);

        vm.prank(updater1);
        capAutomator.renounceRole(UPDATE_ROLE, updater1);

        assertEq(capAutomator.getRoleMemberCount(UPDATE_ROLE), 1);
        assertEq(capAutomator.getRoleMember(UPDATE_ROLE, 0),   updater2);

        // Test renouncing DEFAULT_ADMIN_ROLE
        assertEq(capAutomator.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);

        vm.prank(admin);
        capAutomator.renounceRole(DEFAULT_ADMIN_ROLE, admin);

        assertEq(capAutomator.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 0);
    }

}

contract SetSupplyCapConfigTests is CapAutomatorUnitTestBase {

    function test_setSupplyCapConfig_noAuth() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                DEFAULT_ADMIN_ROLE
            )
        );
        capAutomator.setSupplyCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );

        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );
    }

    function test_setSupplyCapConfig_zeroCap() public {
        vm.expectRevert("CapAutomator/zero-cap");
        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            0,
            0,
            12 hours
        );

        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            2,
            1,
            12 hours
        );
    }

    function test_setSupplyCapConfig_zeroGap() public {
        vm.expectRevert("CapAutomator/zero-gap");
        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            2,
            0,
            12 hours
        );

        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            2,
            1,
            12 hours
        );
    }

    function test_setSupplyCapConfig_invalidCap() public {
        assertEq(ReserveConfiguration.MAX_VALID_SUPPLY_CAP, 68_719_476_735);

        vm.expectRevert("CapAutomator/invalid-cap");
        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            ReserveConfiguration.MAX_VALID_SUPPLY_CAP + 1,
            1_000,
            12 hours
        );

        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            ReserveConfiguration.MAX_VALID_SUPPLY_CAP,
            1_000,
            12 hours
        );
    }

    function test_setSupplyCapConfig_invalidGap() public {
        vm.expectRevert("CapAutomator/invalid-gap");
        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000,
            10_001,
            12 hours
        );

        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000,
            10_000,
            12 hours
        );
    }

    function test_setSupplyCapConfig_invalidCooldown() public {
        vm.expectRevert("CapAutomator/uint48-cast");
        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000,
            1_000,
            uint256(type(uint48).max) + 1
        );

        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000,
            1_000,
            uint256(type(uint48).max)
        );
    }

    function test_setSupplyCapConfig() public {
        (
            uint48 max,
            uint48 gap,
            uint48 increaseCooldown,
            uint48 lastUpdateBlock,
            uint48 lastIncreaseTime
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(max,              0);
        assertEq(gap,              0);
        assertEq(increaseCooldown, 0);
        assertEq(lastUpdateBlock,  0);
        assertEq(lastIncreaseTime, 0);

        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );

        (
            max,
            gap,
            increaseCooldown,
            lastUpdateBlock,
            lastIncreaseTime
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(max,              10_000);
        assertEq(gap,              1_000);
        assertEq(increaseCooldown, 12 hours);
        assertEq(lastUpdateBlock,  0);
        assertEq(lastIncreaseTime, 0);
    }

    function test_setSupplyCapConfig_reconfigure() public {
        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );

        (
            uint48 max,
            uint48 gap,
            uint48 increaseCooldown,
            ,
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(max,              10_000);
        assertEq(gap,              1_000);
        assertEq(increaseCooldown, 12 hours);

        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            13_000,
            1_300,
            24 hours
        );

        (
            max,
            gap,
            increaseCooldown,
            ,
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(max,              13_000);
        assertEq(gap,              1_300);
        assertEq(increaseCooldown, 24 hours);
    }

    function test_setSupplyCapConfig_preserveUpdateTrackers() public {
        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );

        (
            ,,,
            uint48 lastUpdateBlock,
            uint48 lastIncreaseTime
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(lastUpdateBlock,  0);
        assertEq(lastIncreaseTime, 0);

        vm.roll(120_000);
        vm.warp(12 hours);
        vm.prank(updater1);
        capAutomator.exec(asset);

        (
            ,,, 
            uint48 postExecUpdateBlock,
            uint48 postExecIncreaseTime
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(postExecUpdateBlock,  120_000);
        assertEq(postExecIncreaseTime, 12 hours);

        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            20_000,
            2_000,
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
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                DEFAULT_ADMIN_ROLE
            )
        );
        capAutomator.setBorrowCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );

        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );
    }

    function test_setBorrowCapConfig_zeroCap() public {
        vm.expectRevert("CapAutomator/zero-cap");
        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            0,
            0,
            12 hours
        );

        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            2,
            1,
            12 hours
        );
    }

    function test_setBorrowCapConfig_zeroGap() public {
        vm.expectRevert("CapAutomator/zero-gap");
        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            2,
            0,
            12 hours
        );

        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            2,
            1,
            12 hours
        );
    }

    function test_setBorrowCapConfig_invalidCap() public {
        assertEq(ReserveConfiguration.MAX_VALID_BORROW_CAP, 68_719_476_735);

        vm.expectRevert("CapAutomator/invalid-cap");
        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            ReserveConfiguration.MAX_VALID_BORROW_CAP + 1,
            1_000,
            12 hours
        );

        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            ReserveConfiguration.MAX_VALID_BORROW_CAP,
            1_000,
            12 hours
        );
    }

    function test_setBorrowCapConfig_invalidGap() public {
        vm.expectRevert("CapAutomator/invalid-gap");
        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000,
            10_001,
            12 hours
        );

        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000,
            10_000,
            12 hours
        );
    }

    function test_setBorrowCapConfig_invalidCooldown() public {
        vm.expectRevert("CapAutomator/uint48-cast");
        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000,
            1_000,
            uint256(type(uint48).max) + 1
        );

        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000,
            1_000,
            uint256(type(uint48).max)
        );
    }

    function test_setBorrowCapConfig() public {
        (
            uint48 max,
            uint48 gap,
            uint48 increaseCooldown,
            uint48 lastUpdateBlock,
            uint48 lastIncreaseTime
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(max,              0);
        assertEq(gap,              0);
        assertEq(increaseCooldown, 0);
        assertEq(lastUpdateBlock,  0);
        assertEq(lastIncreaseTime, 0);

        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );

        (
            max,
            gap,
            increaseCooldown,
            lastUpdateBlock,
            lastIncreaseTime
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(max,              10_000);
        assertEq(gap,              1_000);
        assertEq(increaseCooldown, 12 hours);
        assertEq(lastUpdateBlock,  0);
        assertEq(lastIncreaseTime, 0);
    }

    function test_setBorrowCapConfig_reconfigure() public {
        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );

        (
            uint48 max,
            uint48 gap,
            uint48 increaseCooldown,
            ,
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(max,              10_000);
        assertEq(gap,              1_000);
        assertEq(increaseCooldown, 12 hours);

        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            13_000,
            1_300,
            24 hours
        );

        (
            max,
            gap,
            increaseCooldown,
            ,
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(max,              13_000);
        assertEq(gap,              1_300);
        assertEq(increaseCooldown, 24 hours);
    }

    function test_setBorrowCapConfig_preserveUpdateTrackers() public {
        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );

        (
            ,,, 
            uint48 lastUpdateBlock,
            uint48 lastIncreaseTime
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(lastUpdateBlock,  0);
        assertEq(lastIncreaseTime, 0);

        vm.roll(600);
        vm.warp(12 hours);

        vm.prank(updater1);
        capAutomator.exec(asset);

        (
            ,,,
            uint48 postExecUpdateBlock,
            uint48 postExecIncreaseTime
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(postExecUpdateBlock,  600);
        assertEq(postExecIncreaseTime, 12 hours);

        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            20_000,
            2_000,
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
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                DEFAULT_ADMIN_ROLE
            )
        );
        capAutomator.removeSupplyCapConfig(asset);
    }

    function test_removeSupplyCapConfig_nonexistentConfig() public {
        vm.prank(admin);
        vm.expectRevert("CapAutomator/nonexistent-config");
        capAutomator.removeSupplyCapConfig(asset);
    }

    function test_removeSupplyCapConfig() public {
        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );

        vm.roll(24);
        vm.warp(24 hours);

        vm.prank(updater1);
        capAutomator.execSupply(asset);

        (
            uint48 max,
            uint48 gap,
            uint48 increaseCooldown,
            uint48 lastUpdateBlock,
            uint48 lastIncreaseTime
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(max,              10_000);
        assertEq(gap,              1_000);
        assertEq(increaseCooldown, 12 hours);
        assertEq(lastUpdateBlock,  24);
        assertEq(lastIncreaseTime, 24 hours);

        vm.prank(admin);
        capAutomator.removeSupplyCapConfig(asset);

        (
            max,
            gap,
            increaseCooldown,
            lastUpdateBlock,
            lastIncreaseTime
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(max,              0);
        assertEq(gap,              0);
        assertEq(increaseCooldown, 0);
        assertEq(lastUpdateBlock,  0);
        assertEq(lastIncreaseTime, 0);
    }

}

contract RemoveBorrowCapConfigTests is CapAutomatorUnitTestBase {

    function test_removeBorrowCapConfig_noAuth() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                DEFAULT_ADMIN_ROLE
            )
        );
        capAutomator.removeBorrowCapConfig(asset);
    }

    function test_removeBorrowCapConfig_nonexistentConfig() public {
        vm.prank(admin);
        vm.expectRevert("CapAutomator/nonexistent-config");
        capAutomator.removeBorrowCapConfig(asset);
    }

    function test_removeBorrowCapConfig() public {
        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );

        vm.roll(36);
        vm.warp(36 hours);

        vm.prank(updater1);
        capAutomator.execBorrow(asset);

        (
            uint48 max,
            uint48 gap,
            uint48 increaseCooldown,
            uint48 lastUpdateBlock,
            uint48 lastIncreaseTime
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(max,              10_000);
        assertEq(gap,              1_000);
        assertEq(increaseCooldown, 12 hours);
        assertEq(lastUpdateBlock,  36);
        assertEq(lastIncreaseTime, 36 hours);

        vm.prank(admin);
        capAutomator.removeBorrowCapConfig(asset);

        (
            max,
            gap,
            increaseCooldown,
            lastUpdateBlock,
            lastIncreaseTime
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(max,              0);
        assertEq(gap,              0);
        assertEq(increaseCooldown, 0);
        assertEq(lastUpdateBlock,  0);
        assertEq(lastIncreaseTime, 0);
    }

}

contract CalculateNewCapTests is Test {

    MockPoolAddressesProvider public mockPoolAddressesProvider;
    MockPool                  public mockPool;
    MockPoolConfigurator      public mockPoolConfigurator;

    address public admin;
    address public updater;

    CapAutomatorHarness public capAutomator;

    function setUp() public {

        admin   = makeAddr("admin");
        updater = makeAddr("updater");

        mockPool                  = new MockPool();
        mockPoolConfigurator      = new MockPoolConfigurator(mockPool);
        mockPoolAddressesProvider = new MockPoolAddressesProvider(
            address(mockPool),
            address(mockPoolConfigurator)
        );

        vm.startPrank(admin);
        capAutomator = new CapAutomatorHarness(
            address(mockPoolAddressesProvider),
            admin,
            updater
        );
        vm.stopPrank();
    }

    function test_calculateNewCap_raiseCap() public {
        uint256 newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                max:              5_000,
                gap:              500,
                increaseCooldown: 0,
                lastUpdateBlock:  0,
                lastIncreaseTime: 0
            }),
            1_900,
            2_000
        );

        assertEq(newCap, 2_400);
    }

    function test_calculateNewCap_notConfigured() public {
        uint256 newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                max:              0,
                gap:              0,
                increaseCooldown: 0,
                lastUpdateBlock:  0,
                lastIncreaseTime: 0
            }),
            1_900,
            2_000
        );

        assertEq(newCap, 2_000);
    }

    function test_calculateNewCap_sameBlock() public {
        vm.roll(250);
        uint256 newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                max:              5_000,
                gap:              500,
                increaseCooldown: 0,
                lastUpdateBlock:  99,
                lastIncreaseTime: 0
            }),
            1_900,
            2_000
        );

        assertEq(newCap, 2_400);

        newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                max:              5_000,
                gap:              500,
                increaseCooldown: 0,
                lastUpdateBlock:  250,
                lastIncreaseTime: 0
            }),
            1_900,
            2_000
        );

        assertEq(newCap, 2_000);
    }

    function test_calculateNewCap_sameCap() public {
        uint256 newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                max:              5_000,
                gap:              500,
                increaseCooldown: 0,
                lastUpdateBlock:  0,
                lastIncreaseTime: 0
            }),
            1_500,
            2_000
        );

        assertEq(newCap, 2_000);
    }

    function test_calculateNewCap_closeToMax() public {
        uint256 newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                max:              5_000,
                gap:              500,
                increaseCooldown: 0,
                lastUpdateBlock:  0,
                lastIncreaseTime: 0
            }),
            4_800,
            4_900
        );

        assertEq(newCap, 5_000);
    }

    function test_calculateNewCap_aboveMax() public {
        uint256 newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                max:              5_000,
                gap:              500,
                increaseCooldown: 0,
                lastUpdateBlock:  0,
                lastIncreaseTime: 0
            }),
            4_800,
            5_200
        );

        assertEq(newCap, 5_000);
    }

    function test_calculateNewCap_cooldown() public {
        uint256 newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                max:              5_000,
                gap:              500,
                increaseCooldown: 12 hours,
                lastUpdateBlock:  0,
                lastIncreaseTime: 12 hours
            }),
            1_900,
            2_000
        );

        assertEq(newCap, 2_000);

        newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                max:              5_000,
                gap:              500,
                increaseCooldown: 12 hours,
                lastUpdateBlock:  0,
                lastIncreaseTime: 12 hours
            }),
            1_200,
            2_000
        );

        assertEq(newCap, 1_700);

        vm.warp(24 hours);
        newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                max:              5_000,
                gap:              500,
                increaseCooldown: 12 hours,
                lastUpdateBlock:  0,
                lastIncreaseTime: 12 hours
            }),
            1_900,
            2_000
        );

        assertEq(newCap, 2_400);
    }

    function test_calculateNewCap_belowState() public {
        uint256 newCap = capAutomator._calculateNewCapExternal(
            CapAutomator.CapConfig({
                max:              4_500,
                gap:              500,
                increaseCooldown: 0,
                lastUpdateBlock:  0,
                lastIncreaseTime: 0
            }),
            4_800,
            5_200
        );

        assertEq(newCap, 4_500);
    }

}

contract ExecSupplyTests is CapAutomatorUnitTestBase {

    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    function test_execSupply_noAuth() public {
        vm.prank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              500,
            increaseCooldown: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this), 
                UPDATE_ROLE
            )
        );
        capAutomator.execSupply(asset);

        // Not even role admin can call execSupply
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                admin,
                UPDATE_ROLE
            )
        );
        capAutomator.execSupply(asset);
    }

    function test_execSupply_afterRevoke() public {
        vm.prank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              500,
            increaseCooldown: 0
        });

        vm.prank(updater1);
        capAutomator.execSupply(asset);

        // Revoke UPDATE_ROLE from updater1
        vm.prank(admin);
        capAutomator.revokeRole(UPDATE_ROLE, updater1);

        assertEq(capAutomator.hasRole(UPDATE_ROLE, updater1), false);

        vm.prank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              1000,
            increaseCooldown: 0
        });

        vm.prank(updater1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                updater1,
                UPDATE_ROLE
            )
        );
        capAutomator.execSupply(asset);
    }

    function test_execSupply() public {
        vm.roll(900);
        vm.warp(900_000);

        vm.prank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              500,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_000);

        (
            ,,,
            uint48 lastUpdateBlockBefore,
            uint48 lastIncreaseTimeBefore
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(lastUpdateBlockBefore,  0);
        assertEq(lastIncreaseTimeBefore, 0);

        vm.prank(updater1);
        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setSupplyCap, (asset, uint256(7_400))),
            1
        );
        uint256 newCap = capAutomator.execSupply(asset);
        
        assertEq(newCap, 7_400);

        // (scaledTotalSupply + accruedToTreasury) * liquidityIndex + gap
        // = (5700 + 50) * 1.2 + 500 = 6900 + 500 = 7400
        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_400);

        (
            ,,,
            uint48 lastUpdateBlockAfter,
            uint48 lastIncreaseTimeAfter
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(lastUpdateBlockAfter,  900);
        assertEq(lastIncreaseTimeAfter, 900_000);
    }

    function test_execSupply_multipleUpdaters() public {
        vm.roll(900);
        vm.warp(900_000);

        vm.prank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              500,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_000);

        (
            ,,,
            uint48 lastUpdateBlockBefore,
            uint48 lastIncreaseTimeBefore
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(lastUpdateBlockBefore,  0);
        assertEq(lastIncreaseTimeBefore, 0);

        vm.prank(updater1);
        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setSupplyCap, (asset, uint256(7_400))),
            1
        );
        uint256 newCap = capAutomator.execSupply(asset);
        
        assertEq(newCap, 7_400);

        // (scaledTotalSupply + accruedToTreasury) * liquidityIndex + gap
        // = (5700 + 50) * 1.2 + 500 = 6900 + 500 = 7400
        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_400);

        (
            ,,,
            uint48 lastUpdateBlockAfter,
            uint48 lastIncreaseTimeAfter
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(lastUpdateBlockAfter,  900);
        assertEq(lastIncreaseTimeAfter, 900_000);

        vm.roll(1800);
        vm.warp(1800_000);

        vm.prank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              1000,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_400);

        (
            ,,,
            lastUpdateBlockBefore,
            lastIncreaseTimeBefore
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(lastUpdateBlockBefore,  900);
        assertEq(lastIncreaseTimeBefore, 900_000);
        
        vm.prank(updater2);
        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setSupplyCap, (asset, uint256(7_900))),
            1
        );
        newCap = capAutomator.execSupply(asset);

        assertEq(newCap, 7_900);

        // (scaledTotalSupply + accruedToTreasury) * liquidityIndex + gap
        // = (5700 + 50) * 1.2 + 1000 = 6900 + 1000 = 7900
        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_900);

        (
            ,,,
            lastUpdateBlockAfter,
            lastIncreaseTimeAfter
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(lastUpdateBlockAfter,  1800);
        assertEq(lastIncreaseTimeAfter, 1800_000);
    }


    function test_execSupply_differentDecimals() public {
        vm.roll(300);
        vm.warp(300_000);

        mockPool.aToken().__setDecimals(6);
        mockPool.__setATokenScaledTotalSupply(4_500e6);
        mockPool.__setAccruedToTreasury(100e6);
        mockPool.__setLiquidityIndex(1.5e27);

        vm.prank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              500,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_000);

        (
            ,,,
            uint48 lastUpdateBlockBefore,
            uint48 lastIncreaseTimeBefore
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(lastUpdateBlockBefore,  0);
        assertEq(lastIncreaseTimeBefore, 0);
        
        vm.prank(updater1);
        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setSupplyCap, (asset, uint256(7_400))),
            1
        );
        uint256 newCap = capAutomator.execSupply(asset);

        assertEq(newCap, 7_400);

        // (scaledTotalSupply + accruedToTreasury) * liquidityIndex + gap
        // = (5700 + 50) * 1.2 + 500 = 6900 + 500 = 7400
        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_400);

        (
            ,,,
            uint48 lastUpdateBlockAfter,
            uint48 lastIncreaseTimeAfter
        ) = capAutomator.supplyCapConfigs(asset);

        assertEq(lastUpdateBlockAfter,  300);
        assertEq(lastIncreaseTimeAfter, 300_000);
    }

    function test_execSupply_sameCap() public {
        vm.prank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              100,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_000);

        vm.prank(updater1);
        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setSupplyCap, (asset, uint256(7_000))),
            0
        );
        uint256 newCap = capAutomator.execSupply(asset);

        assertEq(newCap, 7_000);

        // (scaledTotalSupply + accruedToTreasury) * liquidityIndex + gap
        // = (5700 + 50) * 1.2 + 100 = 6900 + 100 = 7000
        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_000);
    }

    function test_execSupply_belowState() public {
        vm.prank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              2_000,
            gap:              100,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_000);

        vm.prank(updater1);
        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setSupplyCap, (asset, uint256(2_000))),
            1
        );
        uint256 newCap = capAutomator.execSupply(asset);

        assertEq(newCap, 2_000);

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 2_000);
    }

}

contract ExecBorrowTests is CapAutomatorUnitTestBase {

    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    function test_execBorrow_noAuth() public {
        vm.prank(admin);
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              500,
            increaseCooldown: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                UPDATE_ROLE
            )
        );
        capAutomator.execBorrow(asset);

        // Not even role admin can call execBorrow
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                admin,
                UPDATE_ROLE
            )
        );
        capAutomator.execBorrow(asset);
    }

    function test_execBorrow_afterRevoke() public {
        vm.prank(admin);
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              500,
            increaseCooldown: 0
        });

        vm.prank(updater1);
        capAutomator.execBorrow(asset);

        // Revoke UPDATE_ROLE from updater1
        vm.prank(admin);
        capAutomator.revokeRole(UPDATE_ROLE, updater1);

        assertEq(capAutomator.hasRole(UPDATE_ROLE, updater1), false);

        vm.prank(admin);
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              100,
            increaseCooldown: 0
        });

        vm.prank(updater1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                updater1,
                UPDATE_ROLE
            )
        );
        capAutomator.execBorrow(asset);
    }

    function test_execBorrow() public {
        vm.roll(100);
        vm.warp(100_000);

        vm.prank(admin);
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              500,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_000);

        (
            ,,,
            uint48 lastUpdateBlockBefore,
            uint48 lastIncreaseTimeBefore
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(lastUpdateBlockBefore,  0);
        assertEq(lastIncreaseTimeBefore, 0);

        vm.prank(updater1);
        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setBorrowCap, (asset, uint256(4_400))),
            1
        );
        uint256 newCap = capAutomator.execBorrow(asset);

        assertEq(newCap, 4_400); // totalDebt + gap = 3900 + 500 = 4400

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_400);

        (
            ,,,
            uint48 lastUpdateBlockAfter,
            uint48 lastIncreaseTimeAfter
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(lastUpdateBlockAfter,  100);
        assertEq(lastIncreaseTimeAfter, 100_000);
    }

    function test_execBorrow_multipleUpdaters() public {
        vm.roll(100);
        vm.warp(100_000);

        vm.prank(admin);
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              500,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_000);

        (
            ,,,
            uint48 lastUpdateBlockBefore,
            uint48 lastIncreaseTimeBefore
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(lastUpdateBlockBefore,  0);
        assertEq(lastIncreaseTimeBefore, 0);

        vm.prank(updater1);  
        vm.expectCall(  
            address(mockPoolConfigurator),  
            abi.encodeCall(IPoolConfigurator.setBorrowCap, (asset, uint256(4_400))),  
            1  
        );  
        uint256 newCap = capAutomator.execBorrow(asset);  

        assertEq(newCap, 4_400);  // totalDebt + gap = 3900 + 500 = 4400  
        
        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_400);  

        (
            ,,,
            uint48 lastUpdateBlockAfter,
            uint48 lastIncreaseTimeAfter
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(lastUpdateBlockAfter,  100);
        assertEq(lastIncreaseTimeAfter, 100_000);

        vm.roll(200);
        vm.warp(200_000);

        vm.prank(admin);
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              1000,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_400);

        (
            ,,,
            lastUpdateBlockBefore,
            lastIncreaseTimeBefore
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(lastUpdateBlockBefore,  100);
        assertEq(lastIncreaseTimeBefore, 100_000);

        vm.prank(updater2);
        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setBorrowCap, (asset, uint256(4_900))),
            1
        );
        newCap = capAutomator.execBorrow(asset);

        assertEq(newCap, 4_900); // totalDebt + gap = 3900 + 1000 = 4900

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_900);

        (
            ,,,
            lastUpdateBlockAfter,
            lastIncreaseTimeAfter
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(lastUpdateBlockAfter,  200);
        assertEq(lastIncreaseTimeAfter, 200_000);
    }

    function test_execBorrow_differentDecimals() public {
        vm.roll(200);
        vm.warp(200_000);

        mockPool.debtToken().__setDecimals(6);
        mockPool.__setTotalDebt(3_900e6);

        vm.prank(admin);
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              500,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_000);

        (
            ,,,
            uint48 lastUpdateBlockBefore,
            uint48 lastIncreaseTimeBefore
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(lastUpdateBlockBefore,  0);
        assertEq(lastIncreaseTimeBefore, 0);

        vm.prank(updater1);
        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setBorrowCap, (asset, uint256(4_400))),
            1
        );
        uint256 newCap = capAutomator.execBorrow(asset);

        assertEq(newCap, 4_400); // totalDebt + gap = 3900 + 500 = 4400

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_400);

        (
            ,,,
            uint48 lastUpdateBlockAfter,
            uint48 lastIncreaseTimeAfter
        ) = capAutomator.borrowCapConfigs(asset);

        assertEq(lastUpdateBlockAfter,  200);
        assertEq(lastIncreaseTimeAfter, 200_000);
    }

    function test_execBorrow_sameCap() public {
        vm.prank(admin);
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              100,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_000);

        vm.prank(updater1);
        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setBorrowCap, (asset, uint256(4_000))), 
            0
        );
        uint256 newCap = capAutomator.execBorrow(asset);

        assertEq(newCap, 4_000); // totalDebt + gap = 3900 + 100 = 4000

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_000);
    }

    function test_execBorrow_belowState() public {
        vm.prank(admin);
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              1_000,
            gap:              100,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_000);
        
        vm.prank(updater1);
        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setBorrowCap, (asset, uint256(1_000))),
            1
        );
        uint256 newCap = capAutomator.execBorrow(asset);

        assertEq(newCap, 1_000);

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 1_000);
    }

}

contract ExecTests is CapAutomatorUnitTestBase {

    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    function test_exec_noAuth() public {
        mockPool.__setSupplyCap(7_000);
        mockPool.__setBorrowCap(4_000);

        vm.startPrank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              400,
            increaseCooldown: 0
        });
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              8_000,
            gap:              300,
            increaseCooldown: 0
        });
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                UPDATE_ROLE
            )
        );
        capAutomator.exec(asset);

        // Not even role admin can call exec
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                admin,
                UPDATE_ROLE
            )
        );
        capAutomator.exec(asset);
    }

    function test_exec_afterRevoke() public {
        mockPool.__setSupplyCap(7_000);
        mockPool.__setBorrowCap(4_000);

        vm.startPrank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              400,
            increaseCooldown: 0
        });
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              8_000,
            gap:              300,
            increaseCooldown: 0
        });
        vm.stopPrank();

        vm.prank(updater1);
        capAutomator.exec(asset);

        // Revoke UPDATE_ROLE from updater1
        vm.prank(admin);
        capAutomator.revokeRole(UPDATE_ROLE, updater1);
        
        assertEq(capAutomator.hasRole(UPDATE_ROLE, updater1), false);

        vm.startPrank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              200,
            increaseCooldown: 0
        });
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              8_000,
            gap:              100,
            increaseCooldown: 0
        });
        vm.stopPrank();
        
        vm.prank(updater1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                updater1,
                UPDATE_ROLE
            )
        );
        capAutomator.exec(asset);
    }

    function test_exec() public {
        mockPool.__setSupplyCap(7_000);
        mockPool.__setBorrowCap(4_000);

        vm.startPrank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              400,
            increaseCooldown: 0
        });
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              8_000,
            gap:              300,
            increaseCooldown: 0
        });
        vm.stopPrank();

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_000);
        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_000);

        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setSupplyCap, (asset, uint256(7_300))),
            1
        );

        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setBorrowCap, (asset, uint256(4_200))),
            1
        );
        
        vm.prank(updater1);
        ( uint256 newSupplyCap, uint256 newBorrowCap ) = capAutomator.exec(asset);
        
        // (scaledTotalSupply + accruedToTreasury) * liquidityIndex + gap
        // = (5700 + 50) * 1.2 + 400 = 6900 + 400 = 7300
        assertEq(newSupplyCap, 7_300);
        assertEq(newBorrowCap, 4_200); // totalDebt + gap = 3900 + 300 = 4200

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_300);
        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_200);
    }

    function test_exec_multipleUpdaters() public {
        mockPool.__setSupplyCap(7_000);
        mockPool.__setBorrowCap(4_000);

        vm.startPrank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              400,
            increaseCooldown: 0
        });
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              8_000,
            gap:              300,
            increaseCooldown: 0
        });
        vm.stopPrank();

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_000);
        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_000);

        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setSupplyCap, (asset, uint256(7_300))),
            1
        );
        
        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setBorrowCap, (asset, uint256(4_200))),
            1
        );
        
        vm.prank(updater1);
        ( uint256 newSupplyCap, uint256 newBorrowCap ) = capAutomator.exec(asset);

        // (scaledTotalSupply + accruedToTreasury) * liquidityIndex + gap
        // = (5700 + 50) * 1.2 + 400 = 6900 + 400 = 7300
        assertEq(newSupplyCap, 7_300);
        assertEq(newBorrowCap, 4_200); // totalDebt + gap = 3900 + 300 = 4200

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_300);
        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_200);

        vm.roll(1000);
        vm.warp(1000_000);

        vm.startPrank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              200,
            increaseCooldown: 0
        });
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              8_000,
            gap:              100,
            increaseCooldown: 0
        });
        vm.stopPrank();

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_300);
        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_200);

        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setSupplyCap, (asset, uint256(7_100))),
            1
        );
       
        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setBorrowCap, (asset, uint256(4_000))),
            1
        );

        vm.prank(updater2);
        ( newSupplyCap, newBorrowCap ) = capAutomator.exec(asset);

        // (scaledTotalSupply + accruedToTreasury) * liquidityIndex + gap
        // = (5700 + 50) * 1.2 + 200 = 6900 + 200 = 7100
        assertEq(newSupplyCap, 7_100);
        assertEq(newBorrowCap, 4_000);  // totalDebt + gap = 3900 + 100 = 4000

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_100);
        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_000);
    }

}

contract EventTests is CapAutomatorUnitTestBase {

    // AccessControl events
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    // CapAutomator events
    event SetSupplyCapConfig(
        address indexed asset, 
        uint256 max, 
        uint256 gap, 
        uint256 increaseCooldown
    );
    event SetBorrowCapConfig(
        address indexed asset,
        uint256 max,
        uint256 gap,
        uint256 increaseCooldown
    );

    event RemoveSupplyCapConfig(address indexed asset);
    event RemoveBorrowCapConfig(address indexed asset);

    event UpdateSupplyCap(address indexed asset, uint256 oldSupplyCap, uint256 newSupplyCap);
    event UpdateBorrowCap(address indexed asset, uint256 oldBorrowCap, uint256 newBorrowCap);

    function test_RoleGranted_defaultAdminRole() public {
        address newAdmin = makeAddr("newAdmin");

        vm.prank(admin);
        vm.expectEmit(address(capAutomator));
        emit RoleGranted(DEFAULT_ADMIN_ROLE, newAdmin, admin);
        capAutomator.grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
    }

    function test_RoleGranted_updateRole() public {
        address newUpdater = makeAddr("newUpdater");

        vm.prank(admin);
        vm.expectEmit(address(capAutomator));
        emit RoleGranted(UPDATE_ROLE, newUpdater, admin);
        capAutomator.grantRole(UPDATE_ROLE, newUpdater);
    }

    function test_RoleRevoked_defaultAdminRole() public {
        address newAdmin = makeAddr("newAdmin");

        vm.startPrank(admin);
        capAutomator.grantRole(DEFAULT_ADMIN_ROLE, newAdmin);

        vm.expectEmit(address(capAutomator));
        emit RoleRevoked(DEFAULT_ADMIN_ROLE, newAdmin, admin);
        capAutomator.revokeRole(DEFAULT_ADMIN_ROLE, newAdmin);
        vm.stopPrank();
    }

    function test_RoleRevoked_updateRole() public {
        vm.prank(admin);
        vm.expectEmit(address(capAutomator));
        emit RoleRevoked(UPDATE_ROLE, updater1, admin);
        capAutomator.revokeRole(UPDATE_ROLE, updater1);
    }

    function test_RoleRevoked_renounce() public {
        vm.prank(updater1);
        vm.expectEmit(address(capAutomator));
        emit RoleRevoked(UPDATE_ROLE, updater1, updater1);
        capAutomator.renounceRole(UPDATE_ROLE, updater1);
    }

    function test_SetSupplyCapConfig() public {
        vm.prank(admin);
        vm.expectEmit(address(capAutomator));
        emit SetSupplyCapConfig(
            asset,
            20_000,
            2_000,
            24 hours
        );
        capAutomator.setSupplyCapConfig(
            asset,
            20_000,
            2_000,
            24 hours
        );
    }

    function test_SetBorrowCapConfig() public {
        vm.prank(admin);
        vm.expectEmit(address(capAutomator));
        emit SetBorrowCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );
        capAutomator.setBorrowCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );
    }

    function test_RemoveSupplyCapConfig() public {
        vm.startPrank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            20_000,
            2_000,
            24 hours
        );
        vm.expectEmit(address(capAutomator));
        emit RemoveSupplyCapConfig(asset);
        capAutomator.removeSupplyCapConfig(asset);
        vm.stopPrank();
    }

    function test_RemoveBorrowCapConfig() public {
        vm.startPrank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );
        vm.expectEmit(address(capAutomator));
        emit RemoveBorrowCapConfig(asset);
        capAutomator.removeBorrowCapConfig(asset);
        vm.stopPrank();
    }

    function test_UpdateSupplyCap() public {
        vm.prank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              400,
            increaseCooldown: 0
        });

        vm.prank(updater1);
        vm.expectEmit(address(capAutomator));
        emit UpdateSupplyCap(asset, 7_000, 7_300);
        // (scaledTotalSupply + accruedToTreasury) * liquidityIndex + gap
        // = (5700 + 50) * 1.2 + 400 = 6900 + 400 = 7300
        capAutomator.execSupply(asset);
    }

    function test_UpdateBorrowCap() public {
        vm.prank(admin);
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              8_000,
            gap:              300,
            increaseCooldown: 0
        });

        vm.prank(updater1);
        vm.expectEmit(address(capAutomator));
        emit UpdateBorrowCap(asset, 4_000, 4_200); // totalDebt + gap = 3900 + 300 = 4200
        capAutomator.exec(asset);
    }

}
