// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IDataProvider } from "../../src/interfaces/IDataProvider.sol";

contract MockDataProvider is IDataProvider {

    uint256 aTokenTotalSupply;
    uint256 totalDebt;
    uint256 borrowCap;
    uint256 supplyCap;

    constructor(
        uint256 _aTokenTotalSupply,
        uint256 _totalDebt,
        uint256 _borrowCap,
        uint256 _supplyCap
    ) {
        aTokenTotalSupply = _aTokenTotalSupply;
        totalDebt         = _totalDebt;
        borrowCap         = _borrowCap;
        supplyCap         = _supplyCap;
    }

    function setATokenTotalSupply(uint256 _aTokenTotalSupply) external {
        aTokenTotalSupply = _aTokenTotalSupply;
    }

    function setTotalDebt(uint256 _totalDebt) external {
        totalDebt = _totalDebt;
    }

    function setBorrowCap(uint256 _borrowCap) external {
        borrowCap = _borrowCap;
    }

    function setSupplyCap(uint256 _supplyCap) external {
        supplyCap = _supplyCap;
    }

    function getATokenTotalSupply(address) external view returns (uint256) {
        return aTokenTotalSupply;
    }

    function getTotalDebt(address) external view returns (uint256) {
        return totalDebt;
    }

    function getReserveCaps(address) external view returns (uint256, uint256) {
        return (borrowCap, supplyCap);
    }
}
