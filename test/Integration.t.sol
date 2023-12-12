// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";

import { ReserveConfiguration } from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import { DataTypes }            from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import { WadRayMath }           from "aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol";
import { IACLManager }          from "aave-v3-core/contracts/interfaces/IACLManager.sol";
import { IPool }                from "aave-v3-core/contracts/interfaces/IPool.sol";
import { IPoolConfigurator }    from "aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";
import { IScaledBalanceToken }  from "aave-v3-core/contracts/interfaces/IScaledBalanceToken.sol";

import { CapAutomator } from "../src/CapAutomator.sol";

contract CapAutomatorIntegrationTests is Test {

    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using WadRayMath           for uint256;

    address public constant POOL_ADDRESSES_PROVIDER = 0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE;
    address public constant POOL                    = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
    address public constant POOL_CONFIG             = 0x542DBa469bdE58FAeE189ffB60C6b49CE60E0738;
    address public constant DATA_PROVIDER           = 0xFc21d6d146E6086B8359705C8b28512a983db0cb;
    address public constant ACL_MANAGER             = 0xdA135Cd78A086025BcdC87B038a1C462032b510C;
    address public constant SPARK_PROXY             = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;

    address[] assets;

    CapAutomator public capAutomator;

    IACLManager aclManager = IACLManager(ACL_MANAGER);
    IPool       pool       =       IPool(POOL);

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, 18_721_430);

        capAutomator = new CapAutomator(POOL_ADDRESSES_PROVIDER);

        capAutomator.transferOwnership(SPARK_PROXY);

        vm.prank(SPARK_PROXY);
        aclManager.addRiskAdmin(address(capAutomator));

        assets = pool.getReservesList();
    }

    function test_E2E_increaseBorrow() public {
        for(uint256 i; i < assets.length; i++) {
            DataTypes.ReserveData memory reserveData = pool.getReserveData(assets[i]);

            uint256 preIncreaseBorrowCap = reserveData.configuration.getBorrowCap();
            if (preIncreaseBorrowCap == 0) {
                continue;
            }

            uint256 currentBorrow = ERC20(reserveData.variableDebtTokenAddress).totalSupply() / 10 ** ERC20(reserveData.variableDebtTokenAddress).decimals();

            uint256 preIncreaseBorrowGap = preIncreaseBorrowCap - currentBorrow;

            uint256 newMaxCap = preIncreaseBorrowCap * 2;
            uint256 newGap    = preIncreaseBorrowGap * 2;

            vm.prank(SPARK_PROXY);
            capAutomator.setBorrowCapConfig({
                asset:            assets[i],
                max:              newMaxCap,
                gap:              newGap,
                increaseCooldown: 12 hours
            });

            capAutomator.exec(assets[i]);

            uint256 postIncreaseBorrowCap = pool.getReserveData(assets[i]).configuration.getBorrowCap();

            assertEq(postIncreaseBorrowCap, currentBorrow + newGap);
        }
    }

    function test_E2E_decreaseBorrow() public {
        for(uint256 i; i < assets.length; i++) {
            DataTypes.ReserveData memory reserveData = pool.getReserveData(assets[i]);

            uint256 preDecreaseBorrowCap = reserveData.configuration.getBorrowCap();
            if (preDecreaseBorrowCap == 0) {
                continue;
            }

            uint256 currentBorrow = ERC20(reserveData.variableDebtTokenAddress).totalSupply() / 10 ** ERC20(reserveData.variableDebtTokenAddress).decimals();

            uint256 preDecreaseBorrowGap = preDecreaseBorrowCap - currentBorrow;

            uint256 newGap = preDecreaseBorrowGap / 2;

            vm.prank(SPARK_PROXY);
            capAutomator.setBorrowCapConfig({
                asset:            assets[i],
                max:              preDecreaseBorrowCap,
                gap:              newGap,
                increaseCooldown: 12 hours
            });

            capAutomator.exec(assets[i]);

            uint256 postDecreaseBorrowCap = pool.getReserveData(assets[i]).configuration.getBorrowCap();

            assertEq(postDecreaseBorrowCap, currentBorrow + newGap);
        }
    }

    function test_E2E_increaseSupply() public {
        for(uint256 i; i < assets.length; i++) {
            DataTypes.ReserveData memory reserveData = pool.getReserveData(assets[i]);

            uint256 preIncreaseSupplyCap = reserveData.configuration.getSupplyCap();
            if (preIncreaseSupplyCap == 0) {
                continue;
            }

            uint256 currentSupply = (IScaledBalanceToken(reserveData.aTokenAddress).scaledTotalSupply() + uint256(reserveData.accruedToTreasury)).rayMul(reserveData.liquidityIndex)
                / 10 ** ERC20(reserveData.aTokenAddress).decimals();

            uint256 preIncreaseSupplyGap = preIncreaseSupplyCap - currentSupply;

            uint256 newCap = preIncreaseSupplyCap * 2;
            uint256 newGap = preIncreaseSupplyGap * 2;

            vm.prank(SPARK_PROXY);
            capAutomator.setSupplyCapConfig({
                asset:            assets[i],
                max:              newCap,
                gap:              newGap,
                increaseCooldown: 12 hours
            });

            capAutomator.exec(assets[i]);

            uint256 postIncreaseSupplyCap = pool.getReserveData(assets[i]).configuration.getSupplyCap();

            assertEq(postIncreaseSupplyCap, currentSupply + newGap);
        }
    }

    function test_E2E_decreaseSupply() public {
        for(uint256 i; i < assets.length; i++) {
            DataTypes.ReserveData memory reserveData = pool.getReserveData(assets[i]);

            uint256 preDecreaseSupplyCap = reserveData.configuration.getSupplyCap();
            if (preDecreaseSupplyCap == 0) {
                continue;
            }

            uint256 currentSupply = (IScaledBalanceToken(reserveData.aTokenAddress).scaledTotalSupply() + uint256(reserveData.accruedToTreasury)).rayMul(reserveData.liquidityIndex)
                / 10 ** ERC20(reserveData.aTokenAddress).decimals();

            uint256 preDecreaseSupplyGap = preDecreaseSupplyCap - currentSupply;

            uint256 newGap = preDecreaseSupplyGap / 2;

            vm.prank(SPARK_PROXY);
            capAutomator.setSupplyCapConfig({
                asset:            assets[i],
                max:              preDecreaseSupplyCap,
                gap:              newGap,
                increaseCooldown: 12 hours
            });

            capAutomator.exec(assets[i]);

            uint256 postDecreaseSupplyCap = pool.getReserveData(assets[i]).configuration.getSupplyCap();

            assertEq(postDecreaseSupplyCap, currentSupply + newGap);
        }
    }

}
