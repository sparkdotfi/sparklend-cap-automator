// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IPoolConfigurator } from "./IPoolConfigurator.sol";
import { IDataProvider }     from "./IDataProvider.sol";

interface ICapAutomator {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     *  @dev   Event to log the setting of a new owner.
     *  @param oldOwner The address of the previous owner.
     *  @param newOwner The address of the new owner.
     */
    event SetOwner(address indexed oldOwner, address indexed newOwner);

    /**
     *  @dev   Event to log the setting of a new authority.
     *  @param oldAuthority The address of the previous authority.
     *  @param newAuthority The address of the new authority.
     */
    event SetAuthority(address indexed oldAuthority, address indexed newAuthority);

    // TODO Events

    /**********************************************************************************************/
    /*** Storage Variables                                                                      ***/
    /**********************************************************************************************/

    /**
     *  @dev    Returns the address of the pool configurator.
     *  @return poolConfigurator The address of the pool configurator.
     */
    function poolConfigurator() external view returns (IPoolConfigurator poolConfigurator);

    /**
     *  @dev    Returns the address of the data provider.
     *  @return dataProvider The address of the data provider.
     */
    function dataProvider() external view returns (IDataProvider dataProvider);

    /**
     *  @dev    Returns the address of the authority.
     *  @return authority The address of the authority.
     */
    function authority() external view returns (address authority);

    /**
     *  @dev    Returns the address of the owner.
     *  @return owner The address of the owner.
     */
    function owner() external view returns (address owner);

    /**
     *  @dev lorem ipsum
     *  @param asset lorem ipsum
     *  @return maxCap lorem ipsum
     *  @return capGap lorem ipsum
     *  @return capIncreaseCooldown lorem ipsum
     *  @return lastUpdateBlock lorem ipsum
     *  @return lastIncreaseTime lorem ipsum
     */
    function supplyCapConfigs(address asset) external view returns (
        uint256 maxCap,
        uint256 capGap,
        uint48  capIncreaseCooldown,
        uint48  lastUpdateBlock,
        uint48  lastIncreaseTime
    );

    /**
     *  @dev lorem ipsum
     *  @param asset lorem ipsum
     *  @return maxCap lorem ipsum
     *  @return capGap lorem ipsum
     *  @return capIncreaseCooldown lorem ipsum
     *  @return lastUpdateBlock lorem ipsum
     *  @return lastIncreaseTime lorem ipsum
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
     * @dev   Function to set a new owner, permissioned to owner.
     * @param _owner The address of the new owner.
     */
    function setOwner(address _owner) external;

    /**
     * @dev   Function to set a new authority, permissioned to owner.
     * @param _authority The address of the new authority.
     */
    function setAuthority(address _authority) external;

    /**********************************************************************************************/
    /*** Auth Functions                                                                         ***/
    /**********************************************************************************************/

    /**
     *  @dev lorem ipsum
     *  @param asset lorem ipsum
     *  @param maxCap lorem ipsum
     *  @param capGap lorem ipsum
     *  @param capIncreaseCooldown lorem ipsum
     */
    function setSupplyCapConfig(
        address asset,
        uint256 maxCap,
        uint256 capGap,
        uint256 capIncreaseCooldown
    ) external;

    /**
     *  @dev lorem ipsum
     *  @param asset lorem ipsum
     *  @param maxCap lorem ipsum
     *  @param capGap lorem ipsum
     *  @param capIncreaseCooldown lorem ipsum
     */
    function setBorrowCapConfig(
        address asset,
        uint256 maxCap,
        uint256 capGap,
        uint256 capIncreaseCooldown
    ) external;

    /**
     *  @dev lorem ipsum
     *  @param asset lorem ipsum
     */
    function removeSupplyCapConfig(address asset) external;

    /**
     *  @dev lorem ipsum
     *  @param asset lorem ipsum
     */
    function removeBorrowCapConfig(address asset) external;

    /**********************************************************************************************/
    /*** Public Functions                                                                       ***/
    /**********************************************************************************************/

    /**
     *  @dev lorem ipsum
     *  @param asset lorem ipsum
     *  @return newSupplyCap lorem ipsum
     *  @return newBorrowCap lorem ipsum
     */
    function exec(address asset) external returns (uint256 newSupplyCap, uint256 newBorrowCap);
}
