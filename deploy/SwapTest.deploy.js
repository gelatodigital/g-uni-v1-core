module.exports = async (hre) => {
  if (
    hre.network.name === "mainnet" ||
    hre.network.name === "rinkeby" ||
    hre.network.name === "ropsten"
  ) {
    console.log(
      `!! Deploying SwapTest to mainnet/testnet. Hit ctrl + c to abort`
    );
    await new Promise((r) => setTimeout(r, 20000));
  }

  const { deployments } = hre;
  const { deploy } = deployments;
  const { deployer } = await hre.getNamedAccounts();

  await deploy("SwapTest", {
    from: deployer,
    args: [],
  });
};

module.exports.skip = async (hre) => {
  const skip =
    hre.network.name === "mainnet" ||
    //hre.network.name === "rinkeby" ||
    hre.network.name === "ropsten";

  return skip ? true : false;
};

module.exports.tags = ["SwapTest"];
