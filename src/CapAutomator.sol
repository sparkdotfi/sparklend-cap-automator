// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

contract CapAutomator {

    struct CapConfig {
        uint256 maxCap;
        uint256 maxCapGap;
        uint48  capIncreaseCooldown; // seconds
        uint48  lastUpdateBlock;     // blocks
        uint48  lastIncreaseTime;    // seconds
    }

    mapping(address => CapConfig) public supplyCapConfigs;
    mapping(address => CapConfig) public borrowCapConfigs;

    address public immutable poolConfigurator;

    address public owner;
    address public authority;

    constructor(address _poolConfigurator) {
        poolConfigurator = _poolConfigurator;
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
        uint256 maxCapGap,
        uint256 capIncreaseCooldown
    ) external auth {
        _validateCapConfig(maxCap, capIncreaseCooldown);

        supplyCapConfigs[asset] = CapConfig(
            maxCap,
            maxCapGap,
            uint48(capIncreaseCooldown),
            supplyCapConfigs[asset].lastUpdateBlock,
            supplyCapConfigs[asset].lastIncreaseTime
        );
    }

    function setBorrowCapConfig(
        address asset,
        uint256 maxCap,
        uint256 maxCapGap,
        uint256 capIncreaseCooldown
    ) external auth {
        _validateCapConfig(maxCap, capIncreaseCooldown);

        borrowCapConfigs[asset] = CapConfig(
            maxCap,
            maxCapGap,
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

    function _updateSupplyCapConfig(address asset) internal {
        supplyCapConfigs[asset].lastIncreaseTime = uint48(block.timestamp);
        supplyCapConfigs[asset].lastUpdateBlock  = uint48(block.number);
    }

    function _updateBorrowCapConfig(address asset) internal {
        borrowCapConfigs[asset].lastIncreaseTime = uint48(block.timestamp);
        borrowCapConfigs[asset].lastUpdateBlock  = uint48(block.number);
    }

    function exec(address asset) external {
        _updateSupplyCapConfig(asset);
        _updateBorrowCapConfig(asset);
    }
}
