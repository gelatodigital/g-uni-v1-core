import { ethers, network } from "hardhat";
import { BigNumber } from "bignumber.js";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { getAddresses } from "../hardhat/addresses";

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
  const poolFactory = await ethers.getContractAt(
    "IUniswapV3Factory",
    addresses.UniswapV3Factory,
    signer
  );
  const tx = await poolFactory.createPool(
    addresses.WETH,
    addresses.DAI,
    "3000",
    { gasLimit: 6000000 }
  );
  await tx.wait();
  const poolAddress = await poolFactory.getPool(
    addresses.WETH,
    addresses.DAI,
    "3000"
  );
  const pool = await ethers.getContractAt(
    "IUniswapV3Pool",
    poolAddress,
    signer
  );
  const tx2 = await pool.initialize(encodePriceSqrt("1", "100"), {
    gasLimit: 1000000,
  });
  await tx2.wait();
  const { tick } = await pool.slot0();
  console.log("initial tick:", tick.toString());
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
