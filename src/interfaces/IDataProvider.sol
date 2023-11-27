// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

interface IDataProvider {

    function getATokenTotalSupply(address asset) external view returns (uint256);

    function getTotalDebt(address asset) external view returns (uint256);

    function getReserveCaps(address asset) external view returns (uint256, uint256);

}
