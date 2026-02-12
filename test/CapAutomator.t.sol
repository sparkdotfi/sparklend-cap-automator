// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.22;

import { CapAutomatorUnitTestBase } from "./TestBase.t.sol";

import { IAccessControl } from "../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IPoolConfigurator }    from "../lib/aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";
import { ReserveConfiguration } from "../lib/aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import { DataTypes }            from "../lib/aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

import { ICapAutomator } from "../src/interfaces/ICapAutomator.sol";

import { CapAutomator } from "../src/CapAutomator.sol";

contract ConstructorTests is CapAutomatorUnitTestBase {

    function test_constructor_setsInitialState() external {
        assertEq(capAutomator.pool(),             address(mockPool));
        assertEq(capAutomator.poolConfigurator(), address(mockPoolConfigurator));

        assertEq(capAutomator.hasRole(DEFAULT_ADMIN_ROLE, admin),    true);
        assertEq(capAutomator.hasRole(UPDATE_ROLE,        updater1), true);
        assertEq(capAutomator.hasRole(UPDATE_ROLE,        updater2), true);
    }

    function test_constructor_zeroAddress() external {
        vm.expectRevert("CapAutomator/invalid-admin-address");
        new CapAutomator(address(mockPoolAddressesProvider), address(0), updater1);

        vm.expectRevert("CapAutomator/invalid-updater-address");
        new CapAutomator(address(mockPoolAddressesProvider), admin, address(0));
    }

}

contract GrantRoleTests is CapAutomatorUnitTestBase {

    function test_grantRole_defaultAdminRole_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        capAutomator.grantRole(DEFAULT_ADMIN_ROLE, makeAddr("newAdmin"));
    }

    function test_grantRole_grantsDefaultAdmin() external {
        address newAdmin = makeAddr("newAdmin");

        assertEq(capAutomator.hasRole(DEFAULT_ADMIN_ROLE, newAdmin), false);

        vm.expectEmit(address(capAutomator));
        emit IAccessControl.RoleGranted(DEFAULT_ADMIN_ROLE, newAdmin, admin);

        vm.prank(admin);
        capAutomator.grantRole(DEFAULT_ADMIN_ROLE, newAdmin);

        assertEq(capAutomator.hasRole(DEFAULT_ADMIN_ROLE, newAdmin), true);
    }

    function test_grantRole_updateRole_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        capAutomator.grantRole(UPDATE_ROLE, makeAddr("newUpdater"));
    }

    function test_grantRole_updateRole() external {
        address newUpdater = makeAddr("newUpdater");

        assertEq(capAutomator.hasRole(UPDATE_ROLE, newUpdater), false);

        vm.expectEmit(address(capAutomator));
        emit IAccessControl.RoleGranted(UPDATE_ROLE, newUpdater, admin);

        vm.prank(admin);
        capAutomator.grantRole(UPDATE_ROLE, newUpdater);

        assertEq(capAutomator.hasRole(UPDATE_ROLE, newUpdater), true);
    }

}

contract RenounceRoleTests is CapAutomatorUnitTestBase {

    function test_renounceAdminRole_noAuth() external {
        vm.expectRevert(IAccessControl.AccessControlBadConfirmation.selector);

        vm.prank(unauthorized);
        capAutomator.renounceRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function test_renounceAdminRole() external {
        assertEq(capAutomator.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        vm.expectEmit(address(capAutomator));
        emit IAccessControl.RoleRevoked(DEFAULT_ADMIN_ROLE, admin, admin);

        vm.prank(admin);
        capAutomator.renounceRole(DEFAULT_ADMIN_ROLE, admin);

        assertEq(capAutomator.hasRole(DEFAULT_ADMIN_ROLE, admin), false);
    }

    function test_renounceUpdateRole_noAuth() external {
        vm.expectRevert(IAccessControl.AccessControlBadConfirmation.selector);

        vm.prank(unauthorized);
        capAutomator.renounceRole(UPDATE_ROLE, updater1);
    }

    function test_renounceUpdateRole() external {
        assertEq(capAutomator.hasRole(UPDATE_ROLE, updater1), true);

        vm.expectEmit(address(capAutomator));
        emit IAccessControl.RoleRevoked(UPDATE_ROLE, updater1, updater1);

        vm.prank(updater1);
        capAutomator.renounceRole(UPDATE_ROLE, updater1);

        assertEq(capAutomator.hasRole(UPDATE_ROLE, updater1), false);
    }

}

contract RevokeRoleTests is CapAutomatorUnitTestBase {

    function test_revokeAdminRole_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        capAutomator.revokeRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function test_revokeAdminRole() external {
        address newAdmin = makeAddr("newAdmin");

        vm.prank(admin);
        capAutomator.grantRole(DEFAULT_ADMIN_ROLE, newAdmin);

        assertEq(capAutomator.hasRole(DEFAULT_ADMIN_ROLE, newAdmin), true);

        vm.expectEmit(address(capAutomator));
        emit IAccessControl.RoleRevoked(DEFAULT_ADMIN_ROLE, newAdmin, admin);

        vm.prank(admin);
        capAutomator.revokeRole(DEFAULT_ADMIN_ROLE, newAdmin);

        assertEq(capAutomator.hasRole(DEFAULT_ADMIN_ROLE, newAdmin), false);

        vm.expectEmit(address(capAutomator));
        emit IAccessControl.RoleRevoked(DEFAULT_ADMIN_ROLE, admin, admin);

        vm.prank(admin);
        capAutomator.revokeRole(DEFAULT_ADMIN_ROLE, admin);

        assertEq(capAutomator.hasRole(DEFAULT_ADMIN_ROLE, admin), false);
    }

    function test_revokeUpdateRole_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        capAutomator.revokeRole(UPDATE_ROLE, updater1);

        // Can't revoke role on self, only role admin can revoke the role
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                updater1,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(updater1);
        capAutomator.revokeRole(UPDATE_ROLE, updater1);
    }

    function test_revokeUpdateRole() external {
        assertEq(capAutomator.hasRole(UPDATE_ROLE, updater1), true);

        vm.expectEmit(address(capAutomator));
        emit IAccessControl.RoleRevoked(UPDATE_ROLE, updater1, admin);

        vm.prank(admin);
        capAutomator.revokeRole(UPDATE_ROLE, updater1);

        assertEq(capAutomator.hasRole(UPDATE_ROLE, updater1), false);
    }

}

contract GetRoleAdminTests is CapAutomatorUnitTestBase {

    function test_getRoleAdmin_defaultAdminRole() external {
        assertEq(capAutomator.getRoleAdmin(DEFAULT_ADMIN_ROLE), DEFAULT_ADMIN_ROLE);
    }

    function test_getRoleAdmin_updateRole() external {
        assertEq(capAutomator.getRoleAdmin(UPDATE_ROLE), DEFAULT_ADMIN_ROLE);
    }

}

contract AccessControlEnumerableRolesTests is CapAutomatorUnitTestBase {

    function test_getRoleMemberCount_defaultAdminRole() external {
        assertEq(capAutomator.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);
    }

    function test_getRoleMemberCount_updateRole() external {
        assertEq(capAutomator.getRoleMemberCount(UPDATE_ROLE), 2);
    }

    function test_getRoleMember_defaultAdminRole() external {
        assertEq(capAutomator.getRoleMember(DEFAULT_ADMIN_ROLE, 0), admin);
    }

    function test_getRoleMember_updateRole() external {
        assertEq(capAutomator.getRoleMember(UPDATE_ROLE, 0), updater1);
        assertEq(capAutomator.getRoleMember(UPDATE_ROLE, 1), updater2);
    }

    function test_getRoleMemberCount_afterGrant() external {
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

    function test_getRoleMemberCount_afterRevoke() external {
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

    function test_getRoleMemberCount_afterRenounce() external {
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

    function test_setSupplyCapConfig_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );
    }

    function test_setSupplyCapConfig_zeroCap() external {
        vm.expectRevert("CapAutomator/zero-cap");

        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            0,
            0,
            12 hours
        );
    }

    function test_setSupplyCapConfig_zeroGap() external {
        vm.expectRevert("CapAutomator/zero-gap");

        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            2,
            0,
            12 hours
        );
    }

    function test_setSupplyCapConfig_maxValidSupplyCapBoundary() external {
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

    function test_setSupplyCapConfig_invalidGapBoundary() external {
        vm.expectRevert("CapAutomator/invalid-gap");

        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000,
            10_000 + 1,
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

    function test_setSupplyCapConfig_invalidCooldownBoundary() external {
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

    function test_setSupplyCapConfig() external {
        _assertEmptySupplyCapConfig(asset);

        vm.expectEmit(address(capAutomator));
        emit ICapAutomator.SetSupplyCapConfig(
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

        _assertSupplyCapConfig({
            asset_           : asset,
            max              : 10_000,
            gap              : 1_000,
            increaseCooldown : 12 hours,
            lastUpdateBlock  : 0,
            lastIncreaseTime : 0
        });
    }

    function test_setSupplyCapConfig_reconfigure() external {
        _assertEmptySupplyCapConfig(asset); 

        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );

        _assertSupplyCapConfig({
            asset_           : asset,
            max              : 10_000,
            gap              : 1_000,
            increaseCooldown : 12 hours,
            lastUpdateBlock  : 0,
            lastIncreaseTime : 0
        });

        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            13_000,
            1_300,
            24 hours
        );

        _assertSupplyCapConfig({
            asset_           : asset,
            max              : 13_000,
            gap              : 1_300,
            increaseCooldown : 24 hours,
            lastUpdateBlock  : 0,
            lastIncreaseTime : 0
        });
    }

    function test_setSupplyCapConfig_preserveUpdateTrackers() external {
        _assertEmptySupplyCapConfig(asset);

        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );

        _assertTrackersSupplyCapConfig({
            asset_           : asset,
            lastUpdateBlock  : 0,
            lastIncreaseTime : 0
        });

        vm.roll(100);
        vm.warp(12 hours);

        vm.prank(updater1);
        capAutomator.exec(asset);

        _assertTrackersSupplyCapConfig({
            asset_           : asset,
            lastUpdateBlock  : 100,
            lastIncreaseTime : 12 hours
        });

        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            20_000,
            2_000,
            24 hours
        );

        _assertTrackersSupplyCapConfig({
            asset_           : asset,
            lastUpdateBlock  : 100,
            lastIncreaseTime : 12 hours
        });
    }

}

contract SetBorrowCapConfigTests is CapAutomatorUnitTestBase {

    function test_setBorrowCapConfig_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );
    }

    function test_setBorrowCapConfig_zeroCap() external {
        vm.expectRevert("CapAutomator/zero-cap");

        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            0,
            0,
            12 hours
        );
    }

    function test_setBorrowCapConfig_zeroGap() external {
        vm.expectRevert("CapAutomator/zero-gap");

        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            2,
            0,
            12 hours
        );
    }

    function test_setBorrowCapConfig_invalidCapBoundary() external {
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

    function test_setBorrowCapConfig_invalidGapBoundary() external {
        vm.expectRevert("CapAutomator/invalid-gap");

        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000,
            10_000 + 1,
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

    function test_setBorrowCapConfig_invalidCooldownBoundary() external {
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

    function test_setBorrowCapConfig() external {
        _assertEmptyBorrowCapConfig(asset);

        vm.expectEmit(address(capAutomator));
        emit ICapAutomator.SetBorrowCapConfig(
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

        _assertBorrowCapConfig({
            asset_           : asset,
            max              : 10_000,
            gap              : 1_000,
            increaseCooldown : 12 hours,
            lastUpdateBlock  : 0,
            lastIncreaseTime : 0
        });
    }

    function test_setBorrowCapConfig_reconfigure() external {
        _assertEmptyBorrowCapConfig(asset);

        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );

        _assertBorrowCapConfig({
            asset_           : asset,
            max              : 10_000,
            gap              : 1_000,
            increaseCooldown : 12 hours,
            lastUpdateBlock  : 0,
            lastIncreaseTime : 0
        });

        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            13_000,
            1_300,
            24 hours
        );

        _assertBorrowCapConfig({
            asset_           : asset,
            max              : 13_000,
            gap              : 1_300,
            increaseCooldown : 24 hours,
            lastUpdateBlock  : 0,
            lastIncreaseTime : 0
        });
    }

    function test_setBorrowCapConfig_preserveUpdateTrackers() external {
        _assertEmptyBorrowCapConfig(asset);

        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );

        _assertTrackersBorrowCapConfig({
            asset_           : asset,
            lastUpdateBlock  : 0,
            lastIncreaseTime : 0
        });

        vm.roll(100);
        vm.warp(12 hours);

        vm.prank(updater1);
        capAutomator.exec(asset);

        _assertTrackersBorrowCapConfig({
            asset_           : asset,
            lastUpdateBlock  : 100,
            lastIncreaseTime : 12 hours
        });

        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            20_000,
            2_000,
            24 hours
        );

        _assertTrackersBorrowCapConfig({
            asset_           : asset,
            lastUpdateBlock  : 100,
            lastIncreaseTime : 12 hours
        });
    }

}

contract RemoveSupplyCapConfigTests is CapAutomatorUnitTestBase {

    function test_removeSupplyCapConfig_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        capAutomator.removeSupplyCapConfig(asset);
    }

    function test_removeSupplyCapConfig_nonexistentConfig() external {
        vm.expectRevert("CapAutomator/nonexistent-config");

        vm.prank(admin);
        capAutomator.removeSupplyCapConfig(asset);
    }

    function test_removeSupplyCapConfig() external {
        _assertEmptySupplyCapConfig(asset);

        vm.prank(admin);
        capAutomator.setSupplyCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );

        vm.prank(updater1);
        capAutomator.execSupply(asset);

        _assertSupplyCapConfig({
            asset_           : asset,
            max              : 10_000,
            gap              : 1_000,
            increaseCooldown : 12 hours,
            lastUpdateBlock  : 0,
            lastIncreaseTime : 0
        });

        vm.expectEmit(address(capAutomator));
        emit ICapAutomator.RemoveSupplyCapConfig(asset);

        vm.prank(admin);
        capAutomator.removeSupplyCapConfig(asset);

        _assertEmptySupplyCapConfig(asset);
    }

}

contract RemoveBorrowCapConfigTests is CapAutomatorUnitTestBase {

    function test_removeBorrowCapConfig_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        capAutomator.removeBorrowCapConfig(asset);
    }

    function test_removeBorrowCapConfig_nonexistentConfig() external {
        vm.expectRevert("CapAutomator/nonexistent-config");

        vm.prank(admin);
        capAutomator.removeBorrowCapConfig(asset);
    }

    function test_removeBorrowCapConfig() external {
        _assertEmptyBorrowCapConfig(asset);

        vm.prank(admin);
        capAutomator.setBorrowCapConfig(
            asset,
            10_000,
            1_000,
            12 hours
        );

        vm.prank(updater1);
        capAutomator.execBorrow(asset);

        _assertBorrowCapConfig({
            asset_           : asset,
            max              : 10_000,
            gap              : 1_000,
            increaseCooldown : 12 hours,
            lastUpdateBlock  : 0,
            lastIncreaseTime : 0
        });

        vm.expectEmit(address(capAutomator));
        emit ICapAutomator.RemoveBorrowCapConfig(asset);

        vm.prank(admin);
        capAutomator.removeBorrowCapConfig(asset);

        _assertEmptyBorrowCapConfig(asset);
    }

}

contract CalculateNewCapTests is CapAutomatorUnitTestBase {

    function test_calculateNewCap_raiseCap() external {
        uint256 newCap = capAutomatorHarness._calculateNewCapExternal(
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

    function test_calculateNewCap_notConfigured() external {
        uint256 newCap = capAutomatorHarness._calculateNewCapExternal(
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

    function test_calculateNewCap_sameBlock() external {
        vm.roll(250);

        uint256 newCap = capAutomatorHarness._calculateNewCapExternal(
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

        newCap = capAutomatorHarness._calculateNewCapExternal(
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

    function test_calculateNewCap_sameCap() external {
        uint256 newCap = capAutomatorHarness._calculateNewCapExternal(
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

    function test_calculateNewCap_closeToMax() external {
        uint256 newCap = capAutomatorHarness._calculateNewCapExternal(
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

    function test_calculateNewCap_aboveMax() external {
        uint256 newCap = capAutomatorHarness._calculateNewCapExternal(
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

    function test_calculateNewCap_cooldown() external {
        uint256 newCap = capAutomatorHarness._calculateNewCapExternal(
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

        newCap = capAutomatorHarness._calculateNewCapExternal(
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
        newCap = capAutomatorHarness._calculateNewCapExternal(
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

    function test_calculateNewCap_belowState() external {
        uint256 newCap = capAutomatorHarness._calculateNewCapExternal(
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

    function test_execSupply_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                UPDATE_ROLE
            )
        );

        vm.prank(unauthorized);
        capAutomator.execSupply(asset);

        // Not even role admin can call execSupply
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                admin,
                UPDATE_ROLE
            )
        );

        vm.prank(admin);
        capAutomator.execSupply(asset);
    }

    function test_execSupply() external {
        _assertEmptySupplyCapConfig(asset);

        vm.prank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              500,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_000);

        vm.expectEmit(address(capAutomator));
        emit ICapAutomator.UpdateSupplyCap(asset, 7_000, 7_400);

        vm.prank(updater1);
        uint256 newCap = capAutomator.execSupply(asset);

        assertEq(newCap, 7_400);

        // (scaledTotalSupply + accruedToTreasury) * liquidityIndex + gap
        // = (5700 + 50) * 1.2 + 500 = 6900 + 500 = 7400
        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_400);

        _assertSupplyCapConfig({
            asset_           : asset,
            max              : 10_000,
            gap              : 500,
            increaseCooldown : 0,
            lastUpdateBlock  : 1,
            lastIncreaseTime : 1
        });
    }

    function test_execSupply_differentDecimals() external {
        _assertEmptySupplyCapConfig(asset);

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

        vm.expectEmit(address(capAutomator));
        emit ICapAutomator.UpdateSupplyCap(asset, 7_000, 7_400);

        vm.prank(updater1);
        uint256 newCap = capAutomator.execSupply(asset);

        assertEq(newCap, 7_400);

        // (scaledTotalSupply + accruedToTreasury) * liquidityIndex + gap
        // = (5700 + 50) * 1.2 + 500 = 6900 + 500 = 7400
        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_400);

        _assertSupplyCapConfig({
            asset_           : asset,
            max              : 10_000,
            gap              : 500,
            increaseCooldown : 0,
            lastUpdateBlock  : 1,
            lastIncreaseTime : 1
        });
    }

    function test_execSupply_sameCap() external {
        _assertEmptySupplyCapConfig(asset);

        vm.prank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              100,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_000);

        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setSupplyCap, (asset, uint256(7_000))),
            0
        );

        vm.prank(updater1);
        uint256 newCap = capAutomator.execSupply(asset);

        assertEq(newCap, 7_000);

        // (scaledTotalSupply + accruedToTreasury) * liquidityIndex + gap
        // = (5700 + 50) * 1.2 + 100 = 6900 + 100 = 7000
        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_000);

        _assertSupplyCapConfig({
            asset_           : asset,
            max              : 10_000,
            gap              : 100,
            increaseCooldown : 0,
            lastUpdateBlock  : 0,
            lastIncreaseTime : 0
        });
    }

    function test_execSupply_belowState() external {
        _assertEmptySupplyCapConfig(asset);

        vm.prank(admin);
        capAutomator.setSupplyCapConfig({
            asset:            asset,
            max:              2_000,
            gap:              100,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_000);
        
        vm.expectEmit(address(capAutomator));
        emit ICapAutomator.UpdateSupplyCap(asset, 7_000, 2_000);

        vm.prank(updater1);
        uint256 newCap = capAutomator.execSupply(asset);

        assertEq(newCap, 2_000);

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 2_000);

        _assertSupplyCapConfig({
            asset_           : asset,
            max              : 2_000,
            gap              : 100,
            increaseCooldown : 0,
            lastUpdateBlock  : 1,
            lastIncreaseTime : 0
        });
    }

}

contract ExecBorrowTests is CapAutomatorUnitTestBase {

    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    function test_execBorrow_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                UPDATE_ROLE
            )
        );

        vm.prank(unauthorized);
        capAutomator.execBorrow(asset);

        // Not even role admin can call execBorrow
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                admin,
                UPDATE_ROLE
            )
        );

        vm.prank(admin);
        capAutomator.execBorrow(asset);
    }

    function test_execBorrow() external {
        _assertEmptyBorrowCapConfig(asset);

        vm.prank(admin);
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              500,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_000);

        vm.expectEmit(address(capAutomator));
        emit ICapAutomator.UpdateBorrowCap(asset, 4_000, 4_400);

        vm.prank(updater1);
        uint256 newCap = capAutomator.execBorrow(asset);

        assertEq(newCap, 4_400); // totalDebt + gap = 3900 + 500 = 4400

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_400);

        _assertBorrowCapConfig({
            asset_           : asset,
            max              : 10_000,
            gap              : 500,
            increaseCooldown : 0,
            lastUpdateBlock  : 1,
            lastIncreaseTime : 1
        });
    }

    function test_execBorrow_differentDecimals() external {
        _assertEmptyBorrowCapConfig(asset);

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
        
        vm.expectEmit(address(capAutomator));
        emit ICapAutomator.UpdateBorrowCap(asset, 4_000, 4_400);

        vm.prank(updater1);
        uint256 newCap = capAutomator.execBorrow(asset);

        assertEq(newCap, 4_400); // totalDebt + gap = 3900 + 500 = 4400

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_400);

        _assertBorrowCapConfig({
            asset_           : asset,
            max              : 10_000,
            gap              : 500,
            increaseCooldown : 0,
            lastUpdateBlock  : 1,
            lastIncreaseTime : 1
        });
    }

    function test_execBorrow_sameCap() external {
        _assertEmptyBorrowCapConfig(asset);

        vm.prank(admin);
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              10_000,
            gap:              100,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_000);

        vm.expectCall(
            address(mockPoolConfigurator),
            abi.encodeCall(IPoolConfigurator.setBorrowCap, (asset, uint256(4_000))),
            0
        );

        vm.prank(updater1);
        uint256 newCap = capAutomator.execBorrow(asset);

        assertEq(newCap, 4_000); // totalDebt + gap = 3900 + 100 = 4000

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_000);

        _assertBorrowCapConfig({
            asset_           : asset,
            max              : 10_000,
            gap              : 100,
            increaseCooldown : 0,
            lastUpdateBlock  : 0,
            lastIncreaseTime : 0
        });
    }

    function test_execBorrow_belowState() external {
        _assertEmptyBorrowCapConfig(asset);

        vm.prank(admin);
        capAutomator.setBorrowCapConfig({
            asset:            asset,
            max:              1_000,
            gap:              100,
            increaseCooldown: 0
        });

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_000);

        vm.expectEmit(address(capAutomator));
        emit ICapAutomator.UpdateBorrowCap(asset, 4_000, 1_000);

        vm.prank(updater1);
        uint256 newCap = capAutomator.execBorrow(asset);

        assertEq(newCap, 1_000);

        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 1_000);

        _assertBorrowCapConfig({
            asset_           : asset,
            max              : 1_000,
            gap              : 100,
            increaseCooldown : 0,
            lastUpdateBlock  : 1,
            lastIncreaseTime : 0
        });
    }

}

contract ExecTests is CapAutomatorUnitTestBase {

    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    function test_exec_noAuth() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                UPDATE_ROLE
            )
        );

        vm.prank(unauthorized);
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

    function test_exec() external {
        _assertEmptySupplyCapConfig(asset);
        _assertEmptyBorrowCapConfig(asset);

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

        vm.expectEmit(address(capAutomator));
        emit ICapAutomator.UpdateSupplyCap(asset, 7_000, 7_300);

        vm.expectEmit(address(capAutomator));
        emit ICapAutomator.UpdateBorrowCap(asset, 4_000, 4_200);

        vm.prank(updater1);
        ( uint256 newSupplyCap, uint256 newBorrowCap ) = capAutomator.exec(asset);

        // (scaledTotalSupply + accruedToTreasury) * liquidityIndex + gap
        // = (5700 + 50) * 1.2 + 400 = 6900 + 400 = 7300
        assertEq(newSupplyCap, 7_300);
        assertEq(newBorrowCap, 4_200); // totalDebt + gap = 3900 + 300 = 4200

        assertEq(mockPool.getReserveData(asset).configuration.getSupplyCap(), 7_300);
        assertEq(mockPool.getReserveData(asset).configuration.getBorrowCap(), 4_200);

        _assertSupplyCapConfig({
            asset_           : asset,
            max              : 10_000,
            gap              : 400,
            increaseCooldown : 0,
            lastUpdateBlock  : 1,
            lastIncreaseTime : 1
        });
        _assertBorrowCapConfig({
            asset_           : asset,
            max              : 8_000,
            gap              : 300,
            increaseCooldown : 0,
            lastUpdateBlock  : 1,
            lastIncreaseTime : 1
        });
    }

}
