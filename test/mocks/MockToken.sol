// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

contract MockToken {
    uint256 public totalSupply;

    function setTotalSupply(uint256 _totalSupply) public {
        totalSupply = _totalSupply;
    }
}
