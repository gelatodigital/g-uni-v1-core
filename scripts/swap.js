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
  const metaPool = await ethers.getContractAt(
    "MetaPool",
    network.config.gUNIV3,
    signer
  );
  const uniPoolAddress = await metaPool.currentPool();
  const swapper = await ethers.getContractAt(
    "SwapTest",
    network.config.Swapper,
    signer
  );

  const dai = await ethers.getContractAt(
    ["function approve(address,uint256) external"],
    network.config.DAI,
    signer
  );
  await dai.approve(swapper.address, ethers.utils.parseEther("200"));

  /*const weth = await ethers.getContractAt(
    ["function approve(address,uint256) external"],
    network.config.WETH,
    signer
  );
  await weth.approve(swapper.address, ethers.utils.parseEther("10"));*/

  const tx = await swapper.getSwapResult(
    uniPoolAddress,
    true, //false,
    ethers.utils.parseEther("200"),
    encodePriceSqrt("1", "10000"),
    { gasLimit: 6000000 }
  );
  await tx.wait();

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
