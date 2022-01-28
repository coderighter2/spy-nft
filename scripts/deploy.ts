// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { BigNumber } from "ethers";
import hre, {ethers} from "hardhat";
import { GeneralNFTReward } from "../typechain";

require('dotenv').config()

interface RuleData {
  minMintAmount: BigNumber,
  maxMintAmount: BigNumber,
  costErc20Amount: BigNumber,
  mintErc20: string,
  costErc20: string,
  minBurnTime: BigNumber,
  tLevel: BigNumber,
  canMintMaxGrade: boolean,
  canMintMaxTLevel: boolean
}

let spy_token_address = `${process.env.SPY_TOKEN_BSC_MAIN_NET}`;
let cost_nft_wallet_address = `${process.env.COST_NFT_WALLET_MAIN_NET}`;
let reward_team_wallet_address = `${process.env.REWARD_TEAM_WALLET_MAIN_NET}`;
let reward_pool_address = `${process.env.REWARD_POOL_MAIN_NET}`;

if (hre.network.name == 'bsctest') {
  spy_token_address = `${process.env.SPY_TOKEN_BSC_TEST_NET}`;
  cost_nft_wallet_address = `${process.env.COST_NFT_WALLET_TEST_NET}`;
  reward_team_wallet_address = `${process.env.REWARD_TEAM_WALLET_TEST_NET}`;
  reward_pool_address = `${process.env.REWARD_POOL_TEST_NET}`;
}

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  const [deployer] = await ethers.getSigners();

  
/*
  // We get the contract to deploy
  const SpyNFT = await ethers.getContractFactory("SpyNFT");
  const spyNFT = await SpyNFT.deploy();

  const SpyNFTFactory = await ethers.getContractFactory("SpyNFTFactory");
  const spyNFTFactory = await SpyNFTFactory.deploy(spyNFT.address);

  await spyNFT.addMinter(spyNFTFactory.address);

  const spyNFTMinProxy = await deployMintProxy(spyNFTFactory.address);
  await spyNFTFactory.addGegoRuleProxy(0, spyNFTMinProxy.address);

  const generalNFTReward = await deployNFTReward(spyNFT.address, spyNFTFactory.address);
  const insuranceFund = await deployInsuranceFund(generalNFTReward);

  console.log('NFT :' + spyNFT.address);
  console.log('NFT Factory :' + spyNFTFactory.address);
  console.log('Mint Proxy :' + spyNFTMinProxy.address);
  console.log('GeneralNFTReward :' + generalNFTReward.address);
  console.log('InsuranceFundV1 :' + insuranceFund.address);
  */

  await deployRewardPool();
  const spyNFTMarketplace = await deployMarketplace();
  console.log('NFT Marketplace:' + spyNFTMarketplace.address);
}

async function deployRewardPool() {
  let nftAddr = `${process.env.NFT_MAIN_NET}`;
  let nftFactoryAddr = `${process.env.NFT_FACTORY_MAIN_NET}`;
  let mintProxyAddr = `${process.env.NFT_MINT_PROXY_MAIN_NET}`;
  let spyAddr = `${process.env.SPY_TOKEN_BSC_MAIN_NET}`;
  let costNFTWalletAddr = `${process.env.COST_NFT_WALLET_MAIN_NET}`;

  if (hre.network.name == 'bsctest') {
      nftAddr = `${process.env.NFT_TEST_NET}`;
      nftFactoryAddr = `${process.env.NFT_FACTORY_TEST_NET}`;
      mintProxyAddr = `${process.env.NFT_MINT_PROXY_TEST_NET}`;
      costNFTWalletAddr = `${process.env.COST_NFT_WALLET_TEST_NET}`;
      spyAddr = `${process.env.SPY_TOKEN_BSC_TEST_NET}`;
  }

  const generalNFTReward = await deployNFTReward(nftAddr, nftFactoryAddr);
  const insuranceFund = await deployInsuranceFund(generalNFTReward);

  console.log('GeneralNFTReward :' + generalNFTReward.address);
  console.log('InsuranceFundV1 :' + insuranceFund.address);
}

async function deployMintProxy(factory: string)  {

  const rule: RuleData = {
    minMintAmount: BigNumber.from(0),
    maxMintAmount: BigNumber.from(10).pow(23),
    costErc20Amount: BigNumber.from(0),
    mintErc20: spy_token_address,
    costErc20: spy_token_address,
    minBurnTime: BigNumber.from(0),
    tLevel: BigNumber.from(0),
    canMintMaxGrade: true,
    canMintMaxTLevel: true
  };

  const SpyNFTMintProxy = await ethers.getContractFactory("SpyNFTMintProxy");
  const spyNFTMintProxy = await SpyNFTMintProxy.deploy(cost_nft_wallet_address);
  await spyNFTMintProxy.setFactory(factory);
  await spyNFTMintProxy.setRuleData(
    BigNumber.from(0), 
    rule.minMintAmount,
    rule.maxMintAmount,
    rule.costErc20Amount,
    rule.mintErc20,
    rule.costErc20,
    rule.minBurnTime,
    rule.tLevel,
    rule.canMintMaxGrade,
    rule.canMintMaxTLevel);

  return spyNFTMintProxy;
}

async function deployNFTReward(nft: string, factory: string) {

  const block = await ethers.provider.getBlockNumber();
  const GeneralNFTReward = await ethers.getContractFactory("GeneralNFTReward");

  const timestmap = (await ethers.provider.getBlock(block)).timestamp;
  const generalNFTReward = await GeneralNFTReward.deploy(nft, factory, spy_token_address, timestmap);

  console.log('NFT Reward timestamp :' + timestmap);

  return generalNFTReward;
}

async function deployInsuranceFund(nftReward: GeneralNFTReward) {

  const block = await ethers.provider.getBlockNumber();
  const InsuranceFundV1 = await ethers.getContractFactory("InsuranceFundV1");
  const insuranceFundV1 = await InsuranceFundV1.deploy(spy_token_address, nftReward.address);

  await nftReward.setGovernance(insuranceFundV1.address);
  await insuranceFundV1.setRewardPool(reward_pool_address);
  await insuranceFundV1.setTeamWallet(reward_team_wallet_address);
  await insuranceFundV1.setMaxStakedDego(BigNumber.from(100000));

  return insuranceFundV1;
}

async function deployMarketplace() {

  const SpyNFTMarketplace = await ethers.getContractFactory("SpyNFTMarketplace");
  const spyNFTMarketplace = await SpyNFTMarketplace.deploy();

  return spyNFTMarketplace;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
