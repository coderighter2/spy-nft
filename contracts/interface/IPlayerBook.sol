// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <=0.8.4;


interface IPlayerBook {
    function settleReward( address from,uint256 amount ) external returns (uint256);
    function bindRefer( address from,string calldata  affCode )  external returns (bool);
    function hasRefer(address from) external returns(bool);

}