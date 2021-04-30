const { ethers, network } = require("hardhat");

const op = async (signer) => {
  const metapool = await ethers.getContractAt(
    "MetaPool",
    network.config.GULP,
    signer
  );
  await metapool.burn(ethers.utils.parseEther("8.5"), { gasLimit: 6000000 });
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
