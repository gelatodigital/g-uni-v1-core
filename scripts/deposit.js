const { ethers, network } = require("hardhat");

const op = async (signer) => {
  const metapool = await ethers.getContractAt(
    "MetaPool",
    network.config.GULP,
    signer
  );
  const t0 = await ethers.getContractAt(
    ["function approve(address,uint256) external"],
    network.config.T0,
    signer
  );
  const t1 = await ethers.getContractAt(
    ["function approve(address,uint256) external"],
    network.config.T1,
    signer
  );
  await t0.approve(metapool.address, ethers.utils.parseEther("5000"));
  await t1.approve(metapool.address, ethers.utils.parseEther("5000"));
  await metapool.mint(ethers.utils.parseEther("500"), { gasLimit: 1000000 });
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
