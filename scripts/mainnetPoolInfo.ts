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

const op = async () => {
  const pool = await ethers.getContractAt(
    "IUniswapV3Pool",
    "0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8"
  );

  const { tick, sqrtPriceX96 } = await pool.slot0();
  const liquidity = await pool.liquidity();
  const t = await pool.token0();

  console.log("current tick:", tick.toString());
  console.log("current sqrtPrice:", sqrtPriceX96.toString());
  console.log("current liquidity:", liquidity.toString());
  console.log("token0:", t);
};

(async () => {
  //const [signer] = await ethers.getSigners();
  await op();
})();
