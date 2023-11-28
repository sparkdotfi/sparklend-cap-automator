// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IPoolConfigurator } from "./IPoolConfigurator.sol";
import { IDataProvider }     from "./IDataProvider.sol";

interface ICapAutomator {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     *  @dev Event to log the setting of a new owner.
     *  @param oldOwner The address of the previous owner.
     *  @param newOwner The address of the new owner.
     */
    event SetOwner(address indexed oldOwner, address indexed newOwner);

    /**
     *  @dev Event to log the setting of a new authority.
     *  @param oldAuthority The address of the previous authority.
     *  @param newAuthority The address of the new authority.
     */
    event SetAuthority(address indexed oldAuthority, address indexed newAuthority);

    // TODO Events

    /**********************************************************************************************/
    /*** Storage Variables                                                                      ***/
    /**********************************************************************************************/

    /**
     *  @dev Returns the address of the pool configurator.
     *  @return poolConfigurator The address of the pool configurator.
     */
    function poolConfigurator() external view returns (IPoolConfigurator poolConfigurator);

    /**
     *  @dev Returns the address of the data provider.
     *  @return dataProvider The address of the data provider.
     */
    function dataProvider() external view returns (IDataProvider dataProvider);

    /**
     *  @dev Returns the address of the authority.
     *  @return authority The address of the authority.
     */
    function authority() external view returns (address authority);

    /**
     *  @dev Returns the address of the owner.
     *  @return owner The address of the owner.
     */
    function owner() external view returns (address owner);

    /**
     *  @dev Returns current configuration for automatic supply cap management
     *  @param asset The address of the asset which config is going to be returned
     *  @return maxCap Maximum allowed supply cap
     *  @return capGap A gap between the supply and the supply cap that is being maintained
     *  @return capIncreaseCooldown A mimimum period of time that needs to elapse between consequent cap increases
     *  @return lastUpdateBlock The block of the last cap update
     *  @return lastIncreaseTime The timestamp of the last cap increase
     */
    function supplyCapConfigs(address asset) external view returns (
        uint256 maxCap,
        uint256 capGap,
        uint48  capIncreaseCooldown,
        uint48  lastUpdateBlock,
        uint48  lastIncreaseTime
    );

    /**
     *  @dev Returns current configuration for automatic borrow cap management
     *  @param asset The address of the asset which config is going to be returned
     *  @return maxCap Maximum allowed borrow cap
     *  @return capGap A gap between the borrows and the borrow cap that is being maintained
     *  @return capIncreaseCooldown A mimimum period of time that needs to elapse between consequent cap increases
     *  @return lastUpdateBlock The block of the last cap update
     *  @return lastIncreaseTime The timestamp of the last cap increase
     */
    function borrowCapConfigs(address asset) external view returns (
        uint256 maxCap,
        uint256 capGap,
        uint48  capIncreaseCooldown,
        uint48  lastUpdateBlock,
        uint48  lastIncreaseTime
    );

    /**********************************************************************************************/
    /*** Owner Functions                                                                        ***/
    /**********************************************************************************************/

    /**
     * @dev Function to set a new owner, permissioned to owner.
     * @param _owner The address of the new owner.
     */
    function setOwner(address _owner) external;

    /**
     * @dev Function to set a new authority, permissioned to owner.
     * @param _authority The address of the new authority.
     */
    function setAuthority(address _authority) external;

    /**********************************************************************************************/
    /*** Auth Functions                                                                         ***/
    /**********************************************************************************************/

    /**
     *  @dev Function creating (or re-setting) a configuration for automatic supply cap management
     *  @param asset The address of the asset that is going to be managed
     *  @param maxCap Maximum allowed supply cap
     *  @param capGap A gap between the supply and the supply cap that is being maintained
     *  @param capIncreaseCooldown A mimimum period of time that needs to elapse between consequent cap increases
     */
    function setSupplyCapConfig(
        address asset,
        uint256 maxCap,
        uint256 capGap,
        uint256 capIncreaseCooldown
    ) external;

    /**
     *  @dev Function creating (or re-setting) a configuration for automatic borrow cap management
     *  @param asset The address of the asset that is going to be managed
     *  @param maxCap Maximum allowed borrow cap
     *  @param capGap A gap between the borrows and the borrow cap that is being maintained
     *  @param capIncreaseCooldown A mimimum period of time that needs to elapse between consequent cap increases
     */
    function setBorrowCapConfig(
        address asset,
        uint256 maxCap,
        uint256 capGap,
        uint256 capIncreaseCooldown
    ) external;

    /**
     *  @dev Function removing a configuration for automatic supply cap management
     *  @param asset The address of the asset for which the configuration is going to be removed
     */
    function removeSupplyCapConfig(address asset) external;

    /**
     *  @dev Function removing a configuration for automatic borrow cap management
     *  @param asset The address of the asset for which the configuration is going to be removed
     */
    function removeBorrowCapConfig(address asset) external;

    /**********************************************************************************************/
    /*** Public Functions                                                                       ***/
    /**********************************************************************************************/

    /**
     *  @dev A public function that updates supply and borrow caps on markets of a given asset.
     *  @dev The supply and borrow caps are going to be set to, respectively, the values equal
     *  @dev to the sum of current supply and the supply cap gap and the the sum of current borrows and the borrow cap gap.
     *  @dev The caps are only going to be increased if the required cooldown time has passed.
     *  @dev Calling this function more than once per block will not have any additional effect.
     *  @param asset The address of the asset which caps are going to be updated
     *  @return newSupplyCap A newly set supply cap, or the old one if it was not updated
     *  @return newBorrowCap A newly set borrow cap, or the old one if it was not updated
     */
    function exec(address asset) external returns (uint256 newSupplyCap, uint256 newBorrowCap);
}
