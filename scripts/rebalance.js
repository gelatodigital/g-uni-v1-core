const { ethers, network } = require("hardhat");

const op = async (signer) => {
  const metapool = await ethers.getContractAt(
    "MetaPool",
    network.config.GULP,
    signer
  );
  const poolAddr = await metapool.currentPool();
  const pool = await ethers.getContractAt("IUniswapV3Pool", poolAddr, signer);
  const { tick } = await pool.slot0();
  let tickLow = tick - 1000;
  let tickHigh = tick + 1000;
  while (tickLow % 60 != 0) {
    tickLow = tickLow - 1;
  }
  while (tickHigh % 60 != 0) {
    tickHigh = tickHigh + 1;
  }
  await metapool.rebalance(
    tickLow.toString(),
    tickHigh.toString(),
    "3000",
    ethers.utils.parseEther("1"),
    network.config.T0,
    { gasLimit: 6000000 }
  );
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
