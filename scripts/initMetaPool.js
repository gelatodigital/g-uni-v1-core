const { ethers, network } = require("hardhat");

const op = async (signer) => {
  const metaPoolFactory = await ethers.getContractAt(
    "MetaPoolFactory",
    network.config.MetaPoolFactory,
    signer
  );
  const tx = await metaPoolFactory.createPool(
    network.config.WETH,
    network.config.DAI,
    -887220, // @dev can set your initial lower bound
    887220, // @dev can set your initial upper bound
    { gasLimit: 6000000 }
  );
  await tx.wait();
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
