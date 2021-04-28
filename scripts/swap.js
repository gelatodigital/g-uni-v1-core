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
    network.config.GULP,
    signer
  );
  const uniPoolAddress = await metaPool.currentPool();
  console.log(uniPoolAddress);
  const swapper = await ethers.getContractAt(
    "SwapTest",
    network.config.Swapper,
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
  await t0.approve(swapper.address, ethers.utils.parseEther("10000"));
  await t1.approve(swapper.address, ethers.utils.parseEther("10000"));
  await swapper.getSwapResult(
    uniPoolAddress,
    true,
    ethers.utils.parseEther("100"),
    encodePriceSqrt("1", "1"),
    { gasLimit: 6000000 }
  );
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
