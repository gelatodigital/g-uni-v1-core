const { ethers, network } = require("hardhat");
const bn = require("bignumber.js");

bn.config({ EXPONENTIAL_AT: 999999, DECIMAL_PLACES: 40 });

// returns the sqrt price as a 64x96
const encodePriceSqrt = (reserve1, reserve0) => {
  return new bn(reserve1.toString())
    .div(reserve0.toString())
    .sqrt()
    .multipliedBy(new bn(2).pow(96))
    .integerValue(3)
    .toString();
};

const op = async (signer) => {
  const poolFactory = await ethers.getContractAt(
    "IUniswapV3Factory",
    network.config.UniswapV3Factory,
    signer
  );
  const tx = await poolFactory.createPool(
    network.config.T0,
    network.config.T1,
    "3000",
    { gasLimit: 6000000 }
  );
  await tx.wait();
  const poolAddress = await poolFactory.getPool(
    network.config.T0,
    network.config.T1,
    "3000"
  );
  const pool = await ethers.getContractAt(
    "IUniswapV3Pool",
    poolAddress,
    signer
  );
  const tx2 = await pool.initialize(encodePriceSqrt("100", "1"), {
    gasLimit: 1000000,
  });
  await tx2.wait();
  const s = await pool.slot0();
  console.log("sqrt Price:", s.sqrtPriceX96.toString());
  console.log(s);
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
