import hre, {ethers} from "hardhat";
require('dotenv').config()

interface VerifyArguments {
    address: string
    constructorArguments?: any
    contract?: any
}

async function verifyContract(address: string, args: any, contract: string ) {
    const verifyObj: VerifyArguments = {address}
    if(args){
        verifyObj.constructorArguments = args
    }
    if(contract){
        verifyObj.contract = contract;
    }
    console.log("verifyObj", verifyObj)
    return hre
    .run("verify:verify", verifyObj)
    .then(() =>
      console.log(
        "Contract address verified:",
        address
      )
    );
}

async function main() {

    const [deployer] = await ethers.getSigners();
    let nftRewardAddrV3 = `${process.env.NFT_REWARD_V3_MAIN_NET}`;

    if (hre.network.name == 'bsctest') {
        nftRewardAddrV3 = `${process.env.NFT_REWARD_V3_TEST_NET}`;
    }


    try {
        const implementation = await hre.upgrades.erc1967.getImplementationAddress(nftRewardAddrV3)
        await verifyContract(implementation, [
          
        ], "contracts/GeneralNFTRewardUpgradeableV2.sol:GeneralNFTRewardUpgradeableV2");
    } catch (e) {
        console.log(e);
    }
   
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
