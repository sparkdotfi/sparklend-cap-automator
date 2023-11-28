// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IPoolConfigurator } from "./interfaces/IPoolConfigurator.sol";
import { IDataProvider }     from "./interfaces/IDataProvider.sol";
import { ICapAutomator }     from "./interfaces/ICapAutomator.sol";

contract CapAutomator is ICapAutomator {

    /**********************************************************************************************/
    /*** Declarations and Constructor                                                           ***/
    /**********************************************************************************************/

    struct CapConfig {
        uint256 maxCap;
        uint256 capGap;
        uint48  capIncreaseCooldown; // seconds
        uint48  lastUpdateBlock;     // blocks
        uint48  lastIncreaseTime;    // seconds
    }

    mapping(address => CapConfig) public override supplyCapConfigs;
    mapping(address => CapConfig) public override borrowCapConfigs;

    IPoolConfigurator public override immutable poolConfigurator;
    IDataProvider     public override immutable dataProvider;

    address public override owner;
    address public override authority;

    constructor(IPoolConfigurator _poolConfigurator, IDataProvider _dataProvider) {
        poolConfigurator = _poolConfigurator;
        dataProvider     = _dataProvider;
        owner            = msg.sender;
    }

    /**********************************************************************************************/
    /*** Modifiers                                                                              ***/
    /**********************************************************************************************/

    modifier onlyOwner {
        require(msg.sender == owner, "CapAutomator/only-owner");
        _;
    }

    modifier auth {
        require(msg.sender == authority, "CapAutomator/not-authorized");
        _;
    }

    /**********************************************************************************************/
    /*** Owner Functions                                                                        ***/
    /**********************************************************************************************/

    function setOwner(address _owner) external onlyOwner {
        emit SetOwner(owner, _owner);
        owner = _owner;
    }

    function setAuthority(address _authority) external onlyOwner {
        emit SetAuthority(authority, _authority);
        authority = _authority;
    }

    /**********************************************************************************************/
    /*** Auth Functions                                                                         ***/
    /**********************************************************************************************/

    function setSupplyCapConfig(
        address asset,
        uint256 maxCap,
        uint256 capGap,
        uint256 capIncreaseCooldown
    ) external auth {
        _validateCapConfig(maxCap, capIncreaseCooldown);

        supplyCapConfigs[asset] = CapConfig(
            maxCap,
            capGap,
            uint48(capIncreaseCooldown),
            supplyCapConfigs[asset].lastUpdateBlock,
            supplyCapConfigs[asset].lastIncreaseTime
        );

        emit SetSupplyCapConfig(
            asset,
            maxCap,
            capGap,
            capIncreaseCooldown
        );
    }

    function setBorrowCapConfig(
        address asset,
        uint256 maxCap,
        uint256 capGap,
        uint256 capIncreaseCooldown
    ) external auth {
        _validateCapConfig(maxCap, capIncreaseCooldown);

        borrowCapConfigs[asset] = CapConfig(
            maxCap,
            capGap,
            uint48(capIncreaseCooldown),
            borrowCapConfigs[asset].lastUpdateBlock,
            borrowCapConfigs[asset].lastIncreaseTime
        );

        emit SetBorrowCapConfig(
            asset,
            maxCap,
            capGap,
            capIncreaseCooldown
        );
    }

    function removeSupplyCapConfig(address asset) external auth {
        delete supplyCapConfigs[asset];

        emit RemoveSupplyCapConfig(asset);
    }

    function removeBorrowCapConfig(address asset) external auth {
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
        uint256 maxCap,
        uint256 capIncreaseCooldown
    ) internal pure {
        require(maxCap > 0,                       "CapAutomator/invalid-cap");
        require(capIncreaseCooldown <= 2**48 - 1, "CapAutomator/invalid-cooldown");
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }

    function _calculateNewCap(
        CapConfig memory capConfig,
        uint256 currentState,
        uint256 currentCap
    ) internal view returns (uint256) {
        uint256 maxCap = capConfig.maxCap;

        if(maxCap == 0) return currentCap;

        uint48 capIncreaseCooldown = capConfig.capIncreaseCooldown;
        uint48 lastUpdateBlock     = capConfig.lastUpdateBlock;
        uint48 lastIncreaseTime    = capConfig.lastIncreaseTime;

        if (lastUpdateBlock == block.number) return currentCap;

        uint256 capGap = capConfig.capGap;

        uint256 newCap =_min(currentState + capGap, maxCap);

        if(
            newCap > currentCap
            && block.timestamp < (lastIncreaseTime + capIncreaseCooldown)
        ) return currentCap;

        return newCap;
    }

    function _updateSupplyCapConfig(address asset) internal returns (uint256) {
          uint256 currentSupply     = dataProvider.getATokenTotalSupply(asset);
        (,uint256 currentSupplyCap) = dataProvider.getReserveCaps(asset);

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
         uint256 currentBorrow      = dataProvider.getTotalDebt(asset);
        (uint256 currentBorrowCap,) = dataProvider.getReserveCaps(asset);

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
