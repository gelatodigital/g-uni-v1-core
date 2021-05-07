import { ethers, network } from "hardhat";
import { BigNumber } from "bignumber.js";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { getAddresses } from "../src/addresses";

const addresses = getAddresses(network.name);

BigNumber.config({ EXPONENTIAL_AT: 999999, DECIMAL_PLACES: 40 });

// returns the sqrt price as a 64x96
const encodePriceSqrt = (reserve1: string, reserve0: string) => {
  return new BigNumber(reserve1.toString())
    .div(reserve0.toString())
    .sqrt()
    .multipliedBy(new BigNumber(2).pow(96))
    .integerValue(3)
    .toString();
};

const op = async (signer: SignerWithAddress) => {
  const metaPool = await ethers.getContractAt(
    "MetaPool",
    addresses.gUNIV3,
    signer
  );
  const uniPoolAddress = await metaPool.currentPool();
  const swapper = await ethers.getContractAt(
    "SwapTest",
    addresses.Swapper,
    signer
  );

  // @dev change the approvals and amount swapped to your needs

  /*const dai = await ethers.getContractAt(
    ["function approve(address,uint256) external"],
    network.config.DAI,
    signer
  );
  await dai.approve(swapper.address, ethers.utils.parseEther("200"));*/

  const weth = await ethers.getContractAt(
    ["function approve(address,uint256) external"],
    addresses.WETH,
    signer
  );
  await weth.approve(swapper.address, ethers.utils.parseEther("1"));

  const tx = await swapper.getSwapResult(
    uniPoolAddress,
    false,
    ethers.utils.parseEther("0.3"),
    encodePriceSqrt("10000", "1"),
    { gasLimit: 6000000 }
  );
  await tx.wait();

  const pool = await ethers.getContractAt(
    "IUniswapV3Pool",
    uniPoolAddress,
    signer
  );

  const { tick } = await pool.slot0();

  console.log("current tick:", tick.toString());
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
