// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <=0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";


import "./ISpyNFTUpgradeable.sol";

interface IERC20WithDecimals is IERC20Upgradeable{

    function decimals() external returns (uint8);
}