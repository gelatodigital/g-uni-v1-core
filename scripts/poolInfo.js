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

  const { sqrtPriceX96, tick } = await pool.slot0();

  console.log(sqrtPriceX96.toString(), tick.toString());
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
