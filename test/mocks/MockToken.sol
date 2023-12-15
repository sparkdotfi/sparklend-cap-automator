// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

contract MockToken {

    /**********************************************************************************************/
    /*** Declarations and Constructor                                                           ***/
    /**********************************************************************************************/

    uint256 public totalSupply;
    uint256 public scaledTotalSupply;
    uint256 public decimals;

    /**********************************************************************************************/
    /*** Mock Functions                                                                         ***/
    /**********************************************************************************************/

    function __setTotalSupply(uint256 _totalSupply) public {
        totalSupply = _totalSupply;
    }

    function __setScaledTotalSupply(uint256 _scaledTotalSupply) public {
        scaledTotalSupply = _scaledTotalSupply;
    }

    function __setDecimals(uint256 _decimals) public {
        decimals = _decimals;
    }

}
