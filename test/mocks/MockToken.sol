// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

contract MockToken {
    uint256 public totalSupply;
    uint256 public scaledTotalSupply;
    uint256 public decimals;

    function setTotalSupply(uint256 _totalSupply) public {
        totalSupply = _totalSupply;
    }

    function setScaledTotalSupply(uint256 _scaledTotalSupply) public {
        scaledTotalSupply = _scaledTotalSupply;
    }

    function setDecimals(uint256 _decimals) public {
        decimals = _decimals;
    }
}
