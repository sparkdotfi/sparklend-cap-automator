// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { CapAutomator } from "../src/CapAutomator.sol";

contract CapAutomatorUnitTestBase is Test {

    address public configurator;
    address public owner;
    address public authority;

    CapAutomator public capAutomator;

    function setUp() public {
        owner        = makeAddr("owner");
        authority    = makeAddr("authority"   );
        configurator = makeAddr("configurator");

        capAutomator = new CapAutomator(configurator);

        capAutomator.setAuthority(authority);
        capAutomator.setOwner(owner);
    }

}

contract ConstructorTests is CapAutomatorUnitTestBase {

    function test_constructor() public {
        capAutomator = new CapAutomator(configurator);

        assertEq(capAutomator.poolConfigurator(), configurator);
        assertEq(capAutomator.owner(),            address(this));
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

contract SetMarketCapsDataTests is CapAutomatorUnitTestBase {

    function test_setMarketCapsData_noAuth() public {
        vm.expectRevert("CapAutomator/not-authorized");
        capAutomator.setMarketCapsData(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            5_000_000,
            500_000,
            12 hours
        );
    }

    function test_setMarketCapsData_invalidCooldown() public {
        vm.expectRevert("CapAutomator/invalid-cooldown");
        vm.prank(authority);
        capAutomator.setMarketCapsData(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            5_000_000,
            500_000,
            2**48
        );
    }

    function test_setMarketCapsData_invalidSupplyCap() public {
        vm.expectRevert("CapAutomator/invalid-supply-cap");
        vm.prank(authority);
        capAutomator.setMarketCapsData(
            makeAddr("asset"),
            0,
            1_000_000,
            5_000_000,
            500_000,
            12 hours
        );
    }

    function test_setMarketCapsData_invalidBorrowCap() public {
        vm.expectRevert("CapAutomator/invalid-borrow-cap");
        vm.prank(authority);
        capAutomator.setMarketCapsData(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            0,
            500_000,
            12 hours
        );
    }

    function test_setMarketCapsData() public {
        (
            uint256 maxSupplyCap,
            uint256 maxSupplyCapGap,
            uint256 maxBorrowCap,
            uint256 maxBorrowCapGap,
            uint48  capIncreaseCooldown,
            uint48  lastUpdateBlock,
            uint48  lastIncreaseTime
        ) = capAutomator.marketCapsData(makeAddr("asset"));

        assertEq(maxSupplyCap,        0);
        assertEq(maxSupplyCapGap,     0);
        assertEq(maxBorrowCap,        0);
        assertEq(maxBorrowCapGap,     0);
        assertEq(capIncreaseCooldown, 0);
        assertEq(lastUpdateBlock,     0);
        assertEq(lastIncreaseTime,    0);

        vm.prank(authority);
        capAutomator.setMarketCapsData(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            5_000_000,
            500_000,
            12 hours
        );


        (
            maxSupplyCap,
            maxSupplyCapGap,
            maxBorrowCap,
            maxBorrowCapGap,
            capIncreaseCooldown,
            lastUpdateBlock,
            lastIncreaseTime
        ) = capAutomator.marketCapsData(makeAddr("asset"));

        assertEq(maxSupplyCap,        10_000_000);
        assertEq(maxSupplyCapGap,     1_000_000);
        assertEq(maxBorrowCap,        5_000_000);
        assertEq(maxBorrowCapGap,     500_000);
        assertEq(capIncreaseCooldown, 12 hours);
        assertEq(lastUpdateBlock,     0);
        assertEq(lastIncreaseTime,    0);
    }

    function test_setMarketCapsData_reconfigure() public {
        vm.prank(authority);
        capAutomator.setMarketCapsData(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            5_000_000,
            500_000,
            12 hours
        );

        (
            uint256 maxSupplyCap,
            uint256 maxSupplyCapGap,
            uint256 maxBorrowCap,
            uint256 maxBorrowCapGap,
            uint48  capIncreaseCooldown,
            ,
        ) = capAutomator.marketCapsData(makeAddr("asset"));

        assertEq(maxSupplyCap,        10_000_000);
        assertEq(maxSupplyCapGap,     1_000_000);
        assertEq(maxBorrowCap,        5_000_000);
        assertEq(maxBorrowCapGap,     500_000);
        assertEq(capIncreaseCooldown, 12 hours);

        vm.prank(authority);
        capAutomator.setMarketCapsData(
            makeAddr("asset"),
            13_000_000,
            1_300_000,
            7_000_000,
            700_000,
            24 hours
        );

        (
            maxSupplyCap,
            maxSupplyCapGap,
            maxBorrowCap,
            maxBorrowCapGap,
            capIncreaseCooldown,
            ,
        ) = capAutomator.marketCapsData(makeAddr("asset"));

        assertEq(maxSupplyCap,        13_000_000);
        assertEq(maxSupplyCapGap,     1_300_000);
        assertEq(maxBorrowCap,        7_000_000);
        assertEq(maxBorrowCapGap,     700_000);
        assertEq(capIncreaseCooldown, 24 hours);
    }

    function test_setMarketCapsData_preserveUpdateTrackers() public {
        vm.prank(authority);
        capAutomator.setMarketCapsData(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            5_000_000,
            500_000,
            12 hours
        );

        (,,,,,
            uint48 lastUpdateBlock,
            uint48 lastIncreaseTime
        ) = capAutomator.marketCapsData(makeAddr("asset"));

        assertEq(lastUpdateBlock,  0);
        assertEq(lastIncreaseTime, 0);

        capAutomator.exec(makeAddr("asset"));

        (,,,,,
            uint48 postExecUpdateBlock,
            uint48 postExecIncreaseTime
        ) = capAutomator.marketCapsData(makeAddr("asset"));

        assertNotEq(postExecUpdateBlock,  0);
        assertNotEq(postExecIncreaseTime, 0);

        vm.prank(authority);
        capAutomator.setMarketCapsData(
            makeAddr("asset"),
            20_000_000,
            2_000_000,
            7_000_000,
            700_000,
            24 hours
        );

        (,,,,,
            uint48 postReconfigUpdateBlock,
            uint48 postReconfigIncreaseTime
        ) = capAutomator.marketCapsData(makeAddr("asset"));

        assertEq(postReconfigUpdateBlock,  postExecUpdateBlock);
        assertEq(postReconfigIncreaseTime, postExecIncreaseTime);
    }

}

contract RemoveMarketCapsDataTests is CapAutomatorUnitTestBase {

    function test_removeMarketCapsData_noAuth() public {
        vm.expectRevert("CapAutomator/not-authorized");
        capAutomator.removeMarketCapsData(makeAddr("asset"));
    }

    function test_removeMarketCapsData() public {

        vm.prank(authority);
        capAutomator.setMarketCapsData(
            makeAddr("asset"),
            10_000_000,
            1_000_000,
            5_000_000,
            500_000,
            12 hours
        );

        (
            uint256 maxSupplyCap,
            uint256 maxSupplyCapGap,
            uint256 maxBorrowCap,
            uint256 maxBorrowCapGap,
            uint48  capIncreaseCooldown,
            ,
        ) = capAutomator.marketCapsData(makeAddr("asset"));

        assertEq(maxSupplyCap,        10_000_000);
        assertEq(maxSupplyCapGap,     1_000_000);
        assertEq(maxBorrowCap,        5_000_000);
        assertEq(maxBorrowCapGap,     500_000);
        assertEq(capIncreaseCooldown, 12 hours);

        vm.prank(authority);
        capAutomator.removeMarketCapsData(makeAddr("asset"));

        (
            maxSupplyCap,
            maxSupplyCapGap,
            maxBorrowCap,
            maxBorrowCapGap,
            capIncreaseCooldown,
            ,
        ) = capAutomator.marketCapsData(makeAddr("asset"));

        assertEq(maxSupplyCap,        0);
        assertEq(maxSupplyCapGap,     0);
        assertEq(maxBorrowCap,        0);
        assertEq(maxBorrowCapGap,     0);
        assertEq(capIncreaseCooldown, 0);
    }
}
