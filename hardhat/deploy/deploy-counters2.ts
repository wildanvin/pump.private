import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy, getOrNull } = hre.deployments;

  // Check if contract was previously deployed
  const existingDeployment = await getOrNull("EncryptedCounter2");
  const isNewDeployment = !existingDeployment;

  const deployed = await deploy("EncryptedCounter2", {
    from: deployer,
    log: true,
  });

  console.log(`***** EncryptedCounter2 contract: `, deployed.address);
};
export default func;
func.id = "deploy_encryptedCounter2"; // id required to prevent reexecution
func.tags = ["EncryptedCounter2"];
