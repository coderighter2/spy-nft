import { BigNumber } from "ethers";
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

    let nftAddr = `${process.env.NFT_MAIN_NET}`;
    let nftFactoryAddr = `${process.env.NFT_FACTORY_MAIN_NET}`;
    let mintProxyAddr = `${process.env.NFT_MINT_PROXY_MAIN_NET}`;
    let nftRewardAddr = `${process.env.NFT_REWARD_MAIN_NET}`;
    let spyAddr = `${process.env.SPY_TOKEN_BSC_MAIN_NET}`;
    let insuranceAddr = `${process.env.INSURANCE_MAIN_NET}`;
    let costNFTWalletAddr = `${process.env.COST_NFT_WALLET_MAIN_NET}`;
    const rewardTimestamp = 1640533586;

    if (hre.network.name == 'bsctest') {
        nftAddr = `${process.env.NFT_TEST_NET}`;
        nftFactoryAddr = `${process.env.NFT_FACTORY_TEST_NET}`;
        mintProxyAddr = `${process.env.NFT_MINT_PROXY_TEST_NET}`;
        costNFTWalletAddr = `${process.env.COST_NFT_WALLET_TEST_NET}`;
        spyAddr = `${process.env.SPY_TOKEN_BSC_TEST_NET}`;
        nftRewardAddr = `${process.env.NFT_REWARD_TEST_NET}`;
        insuranceAddr = `${process.env.INSURANCE_TEST_NET}`
    }
    // try {
    //     await verifyContract(nftAddr, [], "contracts/SpyNFT.sol:SpyNFT");
    // } catch (e) {
    //     console.log(e);
    // }

    // try {
    //     await verifyContract(nftFactoryAddr, [nftAddr], "contracts/SpyNFTFactory.sol:SpyNFTFactory");
    // } catch (e) {
    //     console.log(e);
    // }

    // try {
    //     await verifyContract(nftRewardAddr, [nftAddr, nftFactoryAddr, spyAddr, rewardTimestamp], "contracts/GeneralNFTReward.sol:GeneralNFTReward");
    // } catch (e) {
    //     console.log(e);
    // }

    // try {
    //     await verifyContract(insuranceAddr, [spyAddr, nftRewardAddr], "contracts/InsuranceFundV1.sol:InsuranceFundV1");
    // } catch (e) {
    //     console.log(e);
    // }

    try {
        await verifyContract(mintProxyAddr, [costNFTWalletAddr], "contracts/SpyNFTMintProxy.sol:SpyNFTMintProxy");
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
