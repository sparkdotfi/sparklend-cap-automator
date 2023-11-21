// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

contract CapAutomator {

    struct MarketCapsData {
        uint256 maxSupplyCap;
        uint256 maxSupplyCapGap;
        uint256 maxBorrowCap;
        uint256 maxBorrowCapGap;
        uint48  capIncreaseCooldown; // seconds
        uint48  lastUpdateBlock;     // blocks
        uint48  lastIncreaseTime;    // seconds
    }

    mapping(address => MarketCapsData) public marketCapsData;

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

    function setMarketCapsData(
        address asset,
        uint256 maxSupplyCap,
        uint256 maxSupplyCapGap,
        uint256 maxBorrowCap,
        uint256 maxBorrowCapGap,
        uint256 capIncreaseCooldown
    ) external auth {
        require(capIncreaseCooldown  <= 2**48 - 1, "CapAutomator/invalid-cooldown");
        require(maxSupplyCap > 0,                  "CapAutomator/invalid-supply-cap");
        require(maxBorrowCap > 0,                  "CapAutomator/invalid-borrow-cap");

        marketCapsData[asset] = MarketCapsData(
            maxSupplyCap,
            maxSupplyCapGap,
            maxBorrowCap,
            maxBorrowCapGap,
            uint48(capIncreaseCooldown),
            marketCapsData[asset].lastUpdateBlock,
            marketCapsData[asset].lastIncreaseTime
        );
    }

    function removeMarketCapsData(address asset) external auth {
        delete marketCapsData[asset];
    }

    function exec(address asset) external {
            marketCapsData[asset].lastUpdateBlock  = uint48(block.number);
            marketCapsData[asset].lastIncreaseTime = uint48(block.timestamp);
    }
}
