import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { getAddresses } from "../src/addresses";
import { BigNumber } from "bignumber.js";

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
  const metapool = await ethers.getContractAt(
    "MetaPool",
    addresses.gUNIV3,
    signer
  );
  const poolAddr = await metapool.pool();
  const pool = await ethers.getContractAt("IUniswapV3Pool", poolAddr, signer);
  const { sqrtPriceX96, tick } = await pool.slot0();
  let tickLow = tick - 500;
  let tickHigh = tick + 500;
  while (tickLow % 60 != 0) {
    tickLow = tickLow - 1;
  }
  while (tickHigh % 60 != 0) {
    tickHigh = tickHigh + 1;
  }

  const slippagePrice = sqrtPriceX96.sub(
    sqrtPriceX96.mul(ethers.BigNumber.from("4")).div("100")
  );

  await metapool.rebalance(
    tickLow.toString(),
    tickHigh.toString(),
    slippagePrice, // if swapping ETH for DAI
    5000,
    ethers.utils.parseEther("0.001"),
    addresses.WETH,
    { gasLimit: 6000000 }
  );
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
