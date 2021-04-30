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
    -46560,
    -45540,
    { gasLimit: 6000000 }
  );
  await tx.wait();
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
