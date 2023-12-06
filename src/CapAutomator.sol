// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { Ownable } from "openzeppelin-contracts/access/Ownable.sol";
import { ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";

import { ReserveConfiguration }   from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import { DataTypes }              from 'aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol';
import { WadRayMath }             from 'aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol';
import { IPoolAddressesProvider } from 'aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol';
import { IPool }                  from 'aave-v3-core/contracts/interfaces/IPool.sol';
import { IPoolConfigurator }      from 'aave-v3-core/contracts/interfaces/IPoolConfigurator.sol';

import { ICapAutomator }        from "./interfaces/ICapAutomator.sol";

contract CapAutomator is ICapAutomator, Ownable {

    using WadRayMath for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    /**********************************************************************************************/
    /*** Declarations and Constructor                                                           ***/
    /**********************************************************************************************/

    struct CapConfig {
        uint48 max;              // full tokens
        uint48 gap;              // full tokens
        uint48 increaseCooldown; // seconds
        uint48 lastUpdateBlock;  // blocks
        uint48 lastIncreaseTime; // seconds
    }

    mapping(address => CapConfig) public override supplyCapConfigs;
    mapping(address => CapConfig) public override borrowCapConfigs;

    IPoolConfigurator public override immutable poolConfigurator;
    IPool             public override immutable pool;

    constructor(address poolAddressesProvider) Ownable(msg.sender) {
        pool             = IPool(IPoolAddressesProvider(poolAddressesProvider).getPool());
        poolConfigurator = IPoolConfigurator(IPoolAddressesProvider(poolAddressesProvider).getPoolConfigurator());
    }

    /**********************************************************************************************/
    /*** Owner Functions                                                                        ***/
    /**********************************************************************************************/

    function setSupplyCapConfig(
        address asset,
        uint256 max,
        uint256 gap,
        uint256 increaseCooldown
    ) external onlyOwner {
        _validateCapConfig(max, gap, increaseCooldown);

        // casting from uint256 to uin48 validated in _validateCapConfig
        supplyCapConfigs[asset] = CapConfig(
            uint48(max),
            uint48(gap),
            uint48(increaseCooldown),
            supplyCapConfigs[asset].lastUpdateBlock,
            supplyCapConfigs[asset].lastIncreaseTime
        );

        emit SetSupplyCapConfig(
            asset,
            max,
            gap,
            increaseCooldown
        );
    }

    function setBorrowCapConfig(
        address asset,
        uint256 max,
        uint256 gap,
        uint256 increaseCooldown
    ) external onlyOwner {
        _validateCapConfig(max, gap, increaseCooldown);

        // casting from uint256 to uin48 validated in _validateCapConfig
        borrowCapConfigs[asset] = CapConfig(
            uint48(max),
            uint48(gap),
            uint48(increaseCooldown),
            borrowCapConfigs[asset].lastUpdateBlock,
            borrowCapConfigs[asset].lastIncreaseTime
        );

        emit SetBorrowCapConfig(
            asset,
            max,
            gap,
            increaseCooldown
        );
    }

    function removeSupplyCapConfig(address asset) external onlyOwner {
        delete supplyCapConfigs[asset];

        emit RemoveSupplyCapConfig(asset);
    }

    function removeBorrowCapConfig(address asset) external onlyOwner {
        delete borrowCapConfigs[asset];

        emit RemoveBorrowCapConfig(asset);
    }

    /**********************************************************************************************/
    /*** Public Functions                                                                       ***/
    /**********************************************************************************************/

    function exec(address asset) external returns (uint256 newSupplyCap, uint256 newBorrowCap){
        newSupplyCap = _updateSupplyCapConfig(asset);
        newBorrowCap = _updateBorrowCapConfig(asset);
    }

    /**********************************************************************************************/
    /*** Internal Functions                                                                     ***/
    /**********************************************************************************************/

    function _validateCapConfig(
        uint256 max,
        uint256 gap,
        uint256 increaseCooldown
    ) internal pure {
        require(max > 0,                              "CapAutomator/invalid-cap");
        require(max <= type(uint48).max,              "CapAutomator/invalid-cap");
        require(gap <= type(uint48).max,              "CapAutomator/invalid-gap");
        require(increaseCooldown <= type(uint48).max, "CapAutomator/invalid-cooldown");
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }

    function _calculateNewCap(
        CapConfig memory capConfig,
        uint256 currentState,
        uint256 currentCap
    ) internal view returns (uint256) {
        uint256 max = capConfig.max;

        if(max == 0) return currentCap;

        if (capConfig.lastUpdateBlock == block.number) return currentCap;

        uint256 newCap = _min(currentState + capConfig.gap, max);

        if(
            newCap > currentCap
            && block.timestamp < (capConfig.lastIncreaseTime + capConfig.increaseCooldown)
        ) return currentCap;

        return newCap;
    }

    function _updateSupplyCapConfig(address asset) internal returns (uint256) {
        DataTypes.ReserveData memory reserveData = pool.getReserveData(asset);

        uint256 currentSupplyCap = reserveData.configuration.getSupplyCap();
        uint256 currentSupply    = (ERC20(reserveData.aTokenAddress).totalSupply() + uint256(reserveData.liquidityIndex).rayMul(reserveData.accruedToTreasury))
            / 10 ** ERC20(reserveData.aTokenAddress).decimals();

        uint256 newSupplyCap = _calculateNewCap(
            supplyCapConfigs[asset],
            currentSupply,
            currentSupplyCap
        );

        if(newSupplyCap == currentSupplyCap) return currentSupplyCap;

        emit UpdateSupplyCap(asset, currentSupplyCap, newSupplyCap);

        poolConfigurator.setSupplyCap(asset, newSupplyCap);

        if (newSupplyCap > currentSupplyCap) {
            supplyCapConfigs[asset].lastIncreaseTime = uint48(block.timestamp);
            supplyCapConfigs[asset].lastUpdateBlock  = uint48(block.number);
        } else {
            supplyCapConfigs[asset].lastUpdateBlock = uint48(block.number);
        }

        return newSupplyCap;
    }

    function _updateBorrowCapConfig(address asset) internal returns (uint256) {
        DataTypes.ReserveData memory reserveData = pool.getReserveData(asset);

        uint256 currentBorrowCap = reserveData.configuration.getBorrowCap();
        uint256 currentBorrow    = ERC20(reserveData.variableDebtTokenAddress).totalSupply() / 10 ** ERC20(reserveData.variableDebtTokenAddress).decimals();

        uint256 newBorrowCap = _calculateNewCap(
            borrowCapConfigs[asset],
            currentBorrow,
            currentBorrowCap
        );

        if(newBorrowCap == currentBorrowCap) return currentBorrowCap;

        emit UpdateBorrowCap(asset, currentBorrowCap, newBorrowCap);

        poolConfigurator.setBorrowCap(asset, newBorrowCap);

        if (newBorrowCap > currentBorrowCap) {
            borrowCapConfigs[asset].lastIncreaseTime = uint48(block.timestamp);
            borrowCapConfigs[asset].lastUpdateBlock  = uint48(block.number);
        } else {
            borrowCapConfigs[asset].lastUpdateBlock = uint48(block.number);
        }

        return newBorrowCap;
    }

}
