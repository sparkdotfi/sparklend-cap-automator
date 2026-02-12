// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.22;

import { Test } from "../lib/forge-std/src/Test.sol";

import { DataTypes }  from "../lib/aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import { WadRayMath } from "../lib/aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol";

import { Ethereum }  from "../lib/spark-address-registry/src/Ethereum.sol";
import { SparkLend } from "../lib/spark-address-registry/src/SparkLend.sol";

import { IERC20Like } from "./interfaces/Common.sol";

import {IACLManagerLike, IPoolLike, IScaledBalanceTokenLike } from "./interfaces/IAAVEV3.sol";

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
    
    function _assertEmptySupplyCapConfig(
        address asset_
    ) internal {
        (
            uint48 max_,
            uint48 gap_,
            uint48 increaseCooldown_,
            uint48 lastUpdateBlock_,
            uint48 lastIncreaseTime_
        ) = capAutomator.supplyCapConfigs(asset_);

        assertEq(max_,              0);
        assertEq(gap_,              0);
        assertEq(increaseCooldown_, 0);
        assertEq(lastUpdateBlock_,  0);
        assertEq(lastIncreaseTime_, 0);
    }

    function _assertEmptyBorrowCapConfig(
        address asset_
    ) internal {
        (
            uint48 max_,
            uint48 gap_,
            uint48 increaseCooldown_,
            uint48 lastUpdateBlock_,
            uint48 lastIncreaseTime_
        ) = capAutomator.borrowCapConfigs(asset_);

        assertEq(max_,              0);
        assertEq(gap_,              0);
        assertEq(increaseCooldown_, 0);
        assertEq(lastUpdateBlock_,  0);
        assertEq(lastIncreaseTime_, 0);
    }

    function _assertSupplyCapConfig(
        address asset_,
        uint48 max,
        uint48 gap,
        uint48 increaseCooldown,
        uint48 lastUpdateBlock,
        uint48 lastIncreaseTime
    ) internal {
        (
            uint48 max_,
            uint48 gap_,
            uint48 increaseCooldown_,
            uint48 lastUpdateBlock_,
            uint48 lastIncreaseTime_
        ) = capAutomator.supplyCapConfigs(asset_);

        assertEq(max_,              max);
        assertEq(gap_,              gap);
        assertEq(increaseCooldown_, increaseCooldown);
        assertEq(lastUpdateBlock_,  lastUpdateBlock);
        assertEq(lastIncreaseTime_, lastIncreaseTime);
    }

    function _assertBorrowCapConfig(
        address asset_,
        uint48 max,
        uint48 gap,
        uint48 increaseCooldown,
        uint48 lastUpdateBlock,
        uint48 lastIncreaseTime
    ) internal {
        (
            uint48 max_,
            uint48 gap_,
            uint48 increaseCooldown_,
            uint48 lastUpdateBlock_,
            uint48 lastIncreaseTime_
        ) = capAutomator.borrowCapConfigs(asset_);

        assertEq(max_,              max);
        assertEq(gap_,              gap);
        assertEq(increaseCooldown_, increaseCooldown);
        assertEq(lastUpdateBlock_,  lastUpdateBlock);
        assertEq(lastIncreaseTime_, lastIncreaseTime);
    }

    function _assertTrackersSupplyCapConfig(
        address asset_,
        uint48 lastUpdateBlock,
        uint48 lastIncreaseTime
    ) internal {
        (
            , , ,
            uint48 lastUpdateBlock_,
            uint48 lastIncreaseTime_
        ) = capAutomator.supplyCapConfigs(asset_);

        assertEq(lastUpdateBlock_,  lastUpdateBlock);
        assertEq(lastIncreaseTime_, lastIncreaseTime);
    }

    function _assertTrackersBorrowCapConfig(
        address asset_,
        uint48 lastUpdateBlock,
        uint48 lastIncreaseTime
    ) internal {
        (
            , , ,
            uint48 lastUpdateBlock_,
            uint48 lastIncreaseTime_
        ) = capAutomator.borrowCapConfigs(asset_);

        assertEq(lastUpdateBlock_,  lastUpdateBlock);
        assertEq(lastIncreaseTime_, lastIncreaseTime);
    }

}

contract CapAutomatorIntegrationTestsBase is Test {

    using WadRayMath for uint256;

    address internal constant POOL_ADDRESSES_PROVIDER = SparkLend.POOL_ADDRESSES_PROVIDER;
    address internal constant POOL                    = SparkLend.POOL;
    address internal constant POOL_CONFIG             = SparkLend.POOL_CONFIGURATOR;
    address internal constant DATA_PROVIDER           = SparkLend.PROTOCOL_DATA_PROVIDER;
    address internal constant ACL_MANAGER             = SparkLend.ACL_MANAGER;
    address internal constant SPARK_PROXY             = Ethereum.SPARK_PROXY;
    address internal constant CAP_AUTO_UPDATER        = Ethereum.ALM_RELAYER_MULTISIG;
    address internal constant WETH                    = Ethereum.WETH;
    address internal constant WBTC                    = Ethereum.WBTC;

    address internal user = makeAddr("user");

    address[] internal assets;

    CapAutomator internal capAutomator;

    IACLManagerLike internal aclManager = IACLManagerLike(ACL_MANAGER);
    IPoolLike       internal pool       = IPoolLike(POOL);

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, 18721430);

        vm.prank(SPARK_PROXY);
        capAutomator = new CapAutomator(POOL_ADDRESSES_PROVIDER, SPARK_PROXY, CAP_AUTO_UPDATER);

        vm.prank(SPARK_PROXY);
        aclManager.addRiskAdmin(address(capAutomator));

        assets = pool.getReservesList();
    }

    function _currentATokenSupply(
        DataTypes.ReserveData memory _reserveData
    ) internal view returns (uint256) {
        return
            (
                IScaledBalanceTokenLike(_reserveData.aTokenAddress).scaledTotalSupply()
                + _reserveData.accruedToTreasury
            ).rayMul(_reserveData.liquidityIndex)
            / 10 ** IERC20Like(_reserveData.aTokenAddress).decimals();
    }

    function _currentBorrows(
        DataTypes.ReserveData memory _reserveData
    ) internal view returns (uint256) {
        return
            IERC20Like(_reserveData.variableDebtTokenAddress).totalSupply()
            / 10 ** IERC20Like(_reserveData.variableDebtTokenAddress).decimals();
    }

}
