module.exports = async (hre) => {
  if (
    hre.network.name === "mainnet" ||
    hre.network.name === "rinkeby" ||
    hre.networkname === "ropsten"
  ) {
    console.log(`!! Deploying MetaPoolFactory to mainnet/testnet. Hit ctrl + c to abort`);
    await new Promise(r => setTimeout(r, 30000));
  }

  const { deployments } = hre;
  const { deploy } = deployments;
  const { deployer } = await hre.getNamedAccounts();

  await deploy("MetaPoolFactory", {
    from: deployer,
    args: [
      hre.network.config.addresses.UniswapV3Factory,
      hre.network.config.addresses.Gelato
    ],
  });
};

module.exports.skip = async (hre) => {
  const skip = 
    hre.network.name === "mainnet" ||
    hre.network.name === "rinkeby" ||
    hre.network.name === "ropsten";
  
  return skip ? true : false;
};

module.exports.tags = ["GelatoMPL"];