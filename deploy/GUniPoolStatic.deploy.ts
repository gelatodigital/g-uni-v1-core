import { deployments, getNamedAccounts } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { getAddresses } from "../src/addresses";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  if (
    hre.network.name === "mainnet" ||
    hre.network.name === "rinkeby" ||
    hre.network.name === "ropsten"
  ) {
    console.log(
      `!! Deploying GUniPoolStatic to mainnet. Hit ctrl + c to abort`
    );
    await new Promise((r) => setTimeout(r, 20000));
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const addresses = getAddresses(hre.network.name);

  await deploy("GUniPoolStatic", {
    from: deployer,
    proxy: {
      proxyContract: "EIP173ProxyWithReceive",
    },
    args: [addresses.WethUsdcV3Pool, addresses.Gelato],
  });
};

func.skip = async (hre: HardhatRuntimeEnvironment) => {
  const shouldSkip =
    hre.network.name === "mainnet" ||
    hre.network.name === "rinkeby" ||
    hre.network.name === "ropsten";
  return shouldSkip ? true : false;
};

func.tags = ["GUniPoolStatic"];

export default func;
