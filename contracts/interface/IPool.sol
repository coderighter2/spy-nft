// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <=0.8.4;


interface IPool {
    function totalSupply( ) external view returns (uint256);
    function balanceOf( address player ) external view returns (uint256);
}