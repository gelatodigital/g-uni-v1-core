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
  const poolAddr = await metapool.currentPool();
  const pool = await ethers.getContractAt("IUniswapV3Pool", poolAddr, signer);
  const { tick } = await pool.slot0();
  let tickLow = tick - 500;
  let tickHigh = tick + 500;
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
    encodePriceSqrt("1000000", "1"), // if swapping ETH for DAI
    ethers.utils.parseEther("0.001"),
    addresses.WETH,
    { gasLimit: 6000000 }
  );
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
