import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  // Primero desplegamos el token confidencial que necesitamos
  const tokenDeployed = await deploy("MyConfidentialERC20", {
    from: deployer,
    args: ["Auction Token", "AUCT"],
    log: true,
  });

  console.log(`MyConfidentialERC20 contract: `, tokenDeployed.address);

  // Configuramos los parámetros para la subasta
  const biddingTime = 7 * 24 * 60 * 60; // 1 semana en segundos
  const isStoppable = true;

  // Desplegamos el contrato de subasta
  const auctionDeployed = await deploy("BlindAuction", {
    from: deployer,
    args: [deployer, tokenDeployed.address, biddingTime, isStoppable],
    log: true,
  });

  console.log(`BlindAuction contract: `, auctionDeployed.address);
};

export default func;
func.id = "deploy_blind_auction";
func.tags = ["BlindAuction"];
