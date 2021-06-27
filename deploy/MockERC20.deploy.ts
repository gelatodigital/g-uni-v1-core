import { deployments, getNamedAccounts } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  if (
    hre.network.name === "mainnet" ||
    hre.network.name === "rinkeby" ||
    hre.network.name === "ropsten"
  ) {
    console.log(
      `!! Deploying MockERC20 to ${hre.network.name}. Hit ctrl + c to abort`
    );
    await new Promise((r) => setTimeout(r, 20000));
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("MockERC20", {
    from: deployer,
  });
};

func.skip = async (hre: HardhatRuntimeEnvironment) => {
  const shouldSkip =
    hre.network.name === "mainnet" ||
    hre.network.name === "rinkeby" ||
    hre.network.name === "ropsten";
  return shouldSkip ? true : false;
};

func.tags = ["MockERC20"];

export default func;
