// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { IPoolConfigurator } from "./interfaces/IPoolConfigurator.sol";
import { IDataProvider }     from "./interfaces/IDataProvider.sol";

contract CapAutomator {

    struct CapConfig {
        uint256 maxCap;
        uint256 capGap;
        uint48  capIncreaseCooldown; // seconds
        uint48  lastUpdateBlock;     // blocks
        uint48  lastIncreaseTime;    // seconds
    }

    mapping(address => CapConfig) public supplyCapConfigs;
    mapping(address => CapConfig) public borrowCapConfigs;

    IPoolConfigurator public immutable poolConfigurator;
    IDataProvider     public immutable dataProvider;

    address public owner;
    address public authority;

    constructor(IPoolConfigurator _poolConfigurator, IDataProvider _dataProvider) {
        poolConfigurator = _poolConfigurator;
        dataProvider     = _dataProvider;
        owner            = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "CapAutomator/only-owner");
        _;
    }

    modifier auth {
        require(msg.sender == authority, "CapAutomator/not-authorized");
        _;
    }

    function setOwner(address owner_) external onlyOwner {
        owner = owner_;
    }

    function setAuthority(address authority_) external onlyOwner {
        authority = authority_;
    }

    function _validateCapConfig(
        uint256 maxCap,
        uint256 capIncreaseCooldown
    ) internal pure {
        require(maxCap > 0,                       "CapAutomator/invalid-cap");
        require(capIncreaseCooldown <= 2**48 - 1, "CapAutomator/invalid-cooldown");
    }

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
    }

    function removeSupplyCapConfig(address asset) external auth {
        delete supplyCapConfigs[asset];
    }

    function removeBorrowCapConfig(address asset) external auth {
        delete borrowCapConfigs[asset];
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }

    function _updateSupplyCapConfig(address asset) internal returns (uint256) {
        uint256 maxCap = supplyCapConfigs[asset].maxCap;

        (,uint256 currentSupplyCap) = dataProvider.getReserveCaps(asset);
          uint256 currentSupply     = dataProvider.getATokenTotalSupply(asset);

        if(maxCap == 0) return currentSupplyCap;

        uint48 capIncreaseCooldown = supplyCapConfigs[asset].capIncreaseCooldown;
        uint48 lastUpdateBlock     = supplyCapConfigs[asset].lastUpdateBlock;
        uint48 lastIncreaseTime    = supplyCapConfigs[asset].lastIncreaseTime;

        if (lastUpdateBlock == block.number) return currentSupplyCap;

        uint256 capGap = supplyCapConfigs[asset].capGap;

        uint256 newSupplyCap =_min(currentSupply + capGap, maxCap);

        if(newSupplyCap == currentSupplyCap) return currentSupplyCap;

        if(
            newSupplyCap > currentSupplyCap
            && block.timestamp < (lastIncreaseTime + capIncreaseCooldown)
        ) return currentSupplyCap;

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
        uint256 maxCap = borrowCapConfigs[asset].maxCap;

        // Get current borrows and current max borrow instead of these 0s
        (uint256 currentBorrowCap,) = dataProvider.getReserveCaps(asset);
         uint256 currentBorrow      = dataProvider.getTotalDebt(asset);

        if(maxCap == 0) return currentBorrowCap;

        uint48 capIncreaseCooldown = borrowCapConfigs[asset].capIncreaseCooldown;
        uint48 lastUpdateBlock     = borrowCapConfigs[asset].lastUpdateBlock;
        uint48 lastIncreaseTime    = borrowCapConfigs[asset].lastIncreaseTime;


        if (lastUpdateBlock == block.number) return currentBorrowCap;

        uint256 capGap = borrowCapConfigs[asset].capGap;

        uint256 newBorrowCap =_min(currentBorrow + capGap, maxCap);

        if(newBorrowCap == currentBorrowCap) return currentBorrowCap;

        if(
            newBorrowCap > currentBorrowCap
            && block.timestamp < (lastIncreaseTime + capIncreaseCooldown)
        ) return currentBorrowCap;

        poolConfigurator.setBorrowCap(asset, newBorrowCap);

        if (newBorrowCap > currentBorrowCap) {
            borrowCapConfigs[asset].lastIncreaseTime = uint48(block.timestamp);
            borrowCapConfigs[asset].lastUpdateBlock  = uint48(block.number);
        } else {
            borrowCapConfigs[asset].lastUpdateBlock = uint48(block.number);
        }

        return newBorrowCap;
    }

    function exec(address asset) external returns (uint256 newSupplyCap, uint256 newBorrowCap){
        newSupplyCap = _updateSupplyCapConfig(asset);
        newBorrowCap = _updateBorrowCapConfig(asset);
    }
}
