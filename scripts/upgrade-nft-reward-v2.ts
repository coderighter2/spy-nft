// This script was tested completely
import hre, {ethers} from "hardhat";

require('dotenv').config()

let nftRewardAddr = `${process.env.NFT_REWARD_V3_MAIN_NET}`;

if (hre.network.name == 'bsctest') {
  nftRewardAddr = `${process.env.NFT_REWARD_V3_TEST_NET}`;
}

async function main() {

  const [deployer] = await ethers.getSigners();

  //GeneralNFTRewardUpgradeableV2 was not written yet, but this upgrade script was tested completely
  const GeneralNFTRewardUpgradeableV2 = await hre.ethers.getContractFactory("GeneralNFTRewardUpgradeableV2");
  const nftRewardV2 = await hre.upgrades.upgradeProxy(nftRewardAddr, GeneralNFTRewardUpgradeableV2);
}


main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
