const { ethers, network } = require("hardhat");

const op = async (signer) => {
  const metapool = await ethers.getContractAt(
    "MetaPool",
    network.config.gUNIV3,
    signer
  );
  const weth = await ethers.getContractAt(
    ["function approve(address,uint256) external"],
    network.config.WETH,
    signer
  );
  const dai = await ethers.getContractAt(
    ["function approve(address,uint256) external"],
    network.config.DAI,
    signer
  );

  // @dev change these amounts to your needs
  await weth.approve(metapool.address, ethers.utils.parseEther("10000"));
  await dai.approve(metapool.address, ethers.utils.parseEther("10000"));
  await metapool.mint(ethers.utils.parseEther("1"), { gasLimit: 2000000 });
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
