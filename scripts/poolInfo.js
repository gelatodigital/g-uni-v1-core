const { ethers, network } = require("hardhat");

const op = async (signer) => {
  const metaPool = await ethers.getContractAt(
    "MetaPool",
    network.config.gUNIV3,
    signer
  );
  const uniPoolAddress = await metaPool.currentPool();

  const pool = await ethers.getContractAt(
    "IUniswapV3Pool",
    uniPoolAddress,
    signer
  );

  const { tick } = await pool.slot0();

  console.log("current tick:", tick.toString());

  const r = await pool.observe([3600, 0]);

  console.log(
    "avg tick (last 1 hour):",
    ((r[0][1] - r[0][0]) / 3600).toString()
  );
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
