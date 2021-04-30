const { ethers, network } = require("hardhat");

const op = async (signer) => {
  const dai = await ethers.getContractAt(
    ["function allocateTo(address,uint256) external"],
    network.config.DAI,
    signer
  );
  await dai.allocateTo(
    await signer.getAddress(),
    ethers.utils.parseEther("100"),
    { gasLimit: 6000000 }
  );
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
