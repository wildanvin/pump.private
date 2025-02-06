import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const auctionConfig = {
    minDuration: BigInt(3660),
    maxDuration: BigInt(3660 * 24 * 7),
    allowBidModification: true,
    maxModifications: BigInt(2),
    extensionTime: BigInt(3660 * 24),
    extensionThreshold: BigInt(3660),
    requiredDeposit: BigInt(1_000_000_000_000_000), // 0.001 ETH
    minBidValue: BigInt(1_000_000_000_000_000), // 0.001 token
  };

  const spAuctionDeployed = await deploy("ImprovedSinglePriceAuction2", {
    from: deployer,
    args: [
      "0x4b2b0D5eE2857fF41B40e3820cDfAc8A9cA60d9f", //_tokenForSale
      "0x4b2b0D5eE2857fF41B40e3820cDfAc8A9cA60d9f", //_paymentToken
      "0x4b2b0D5eE2857fF41B40e3820cDfAc8A9cA60d9f", //_beneficiary
      BigInt(1_000_000), //_totalTokens
      BigInt(3660), //_minDuration
      BigInt(3660 * 24 * 7), //_maxDuration
      BigInt(10), //_minParticipants
      auctionConfig, // Correctly passing AuctionConfig as a struct
    ],
    log: true,
  });

  console.log(`Auction contract deployed at: `, spAuctionDeployed.address);

  const spAuctionFactory = await hre.ethers.getContractFactory("ImprovedSinglePriceAuction2");
  const spAuction = spAuctionFactory.attach(spAuctionDeployed.address);
  const startAuction = await spAuction.startAuction();
  await startAuction.wait();
  console.log(`Auction started`);
};

export default func;
func.id = "deploy_sp_blind_auction";
func.tags = ["spBlindAuction"];
