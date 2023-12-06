// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

contract MockPoolAddressesProvider {
    address public pool;
    address public poolConfigurator;

    constructor(address _pool, address _poolConfigurator) {
        pool             = _pool;
        poolConfigurator = _poolConfigurator;
    }

    function getPool() public view returns (address) {
        return pool;
    }

    function getPoolConfigurator() public view returns (address) {
        return poolConfigurator;
    }
}
