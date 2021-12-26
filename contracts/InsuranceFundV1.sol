pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IGeneralNFTReward.sol";

/**
 * A contract to update reward for NFT pool every 7 days
 */
contract InsuranceFundV1 is Ownable {
    IGeneralNFTReward public generalNFTReward;
    IERC20 public spy;

    constructor(
        IERC20 _spy,
        address _generalNFTReward
    ) {
        spy = _spy;
        generalNFTReward = IGeneralNFTReward(_generalNFTReward);
    }

    function approveNFTReward() public {
        spy.approve(address(generalNFTReward), type(uint256).max);
    }

    // set new rewards distributing in 7 days for GeneralNFTRewards
    function notifyReward(uint256 amount) external onlyOwner {
        require(block.timestamp >= generalNFTReward._periodFinish(), "Not time to reset");
        require(spy.balanceOf(address(this)) >= amount, "Not enough balance");
        generalNFTReward.notifyReward(amount);
    }

    // change GeneralNFTRewards
    function changeGeneralNFTGovernance(address governance) external onlyOwner {
        generalNFTReward.setGovernance(governance);
    }
    function setTeamRewardRate( uint256 teamRewardRate ) external onlyOwner {
        generalNFTReward.setTeamRewardRate(teamRewardRate);
    }
    function setPoolRewardRate( uint256  poolRewardRate ) external onlyOwner {
        generalNFTReward.setPoolRewardRate(poolRewardRate);
    }
    function setHarvestInterval( uint256  harvestInterval ) external onlyOwner {
        generalNFTReward.setHarvestInterval(harvestInterval);
    }
    function setRewardPool( address  rewardPool ) external onlyOwner {
        generalNFTReward.setRewardPool(rewardPool);
    }
    function setTeamWallet( address teamwallet ) external onlyOwner {
        generalNFTReward.setTeamWallet(teamwallet);
    }
    function setWithDrawPunishTime( uint256  punishTime ) external onlyOwner {
        generalNFTReward.setWithDrawPunishTime(punishTime);
    }
    function setMaxStakedDego(uint256 amount) external onlyOwner {
        generalNFTReward.setMaxStakedDego(amount);
    }
}