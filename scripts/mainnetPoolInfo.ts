import hre from "hardhat";
import { ethers, network } from "hardhat";
import { BigNumber } from "@ethersproject/bignumber";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { getAddresses } from "../src/addresses";

const addresses = getAddresses(network.name);

function subIn256(x: BigNumber, y: BigNumber): BigNumber {
  const difference = x.sub(y);
  return difference.lt(0)
    ? BigNumber.from(2).pow(256).add(difference)
    : difference;
}

function getCounterfactualFees(
  feeGrowthGlobal: BigNumber,
  feeGrowthOutsideLower: BigNumber,
  feeGrowthOutsideUpper: BigNumber,
  feeGrowthInsideLast: BigNumber,
  tickCurrent: number,
  liquidity: BigNumber,
  tickLower: number,
  tickUpper: number
) {
  let feeGrowthBelow: BigNumber;
  if (tickCurrent >= tickLower) {
    feeGrowthBelow = feeGrowthOutsideLower;
  } else {
    feeGrowthBelow = subIn256(feeGrowthGlobal, feeGrowthOutsideLower);
  }

  let feeGrowthAbove: BigNumber;
  if (tickCurrent < tickUpper) {
    feeGrowthAbove = feeGrowthOutsideUpper;
  } else {
    feeGrowthAbove = subIn256(feeGrowthGlobal, feeGrowthOutsideUpper);
  }

  const feeGrowthInside = subIn256(
    subIn256(feeGrowthGlobal, feeGrowthBelow),
    feeGrowthAbove
  );

  return subIn256(feeGrowthInside, feeGrowthInsideLast)
    .mul(liquidity)
    .div(BigNumber.from(2).pow(128));
}

const op = async (signer: SignerWithAddress) => {
  const metapool = await ethers.getContractAt("MetaPool", addresses.gUNIV3);
  const abi = (await hre.artifacts.readArtifact("IUniswapV3Pool"))["abi"];
  const pool = new ethers.Contract(
    "0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8",
    abi,
    signer.provider
  );

  const {
    tick,
    sqrtPriceX96,
    observationCardinalityNext,
    observationCardinality,
  } = await pool.slot0();
  const feeGlobal0 = await pool.feeGrowthGlobal0X128();
  const feeGlobal1 = await pool.feeGrowthGlobal1X128();
  console.log("current tick:", tick.toString());
  console.log("current sqrtPrice:", sqrtPriceX96.toString());
  console.log(
    "cardinality:",
    observationCardinality.toString(),
    observationCardinalityNext.toString()
  );

  const { tickCumulatives } = await pool.observe([1800, 0]);
  const positionLower = await metapool.currentLowerTick();
  const positionUpper = await metapool.currentUpperTick();
  console.log(
    "ten min avg tick:",
    tickCumulatives[1]
      .sub(tickCumulatives[0])
      .div(ethers.BigNumber.from("1800"))
      .toString()
  );

  const { _liquidity, tokensOwed0, tokensOwed1 } = await pool.positions(
    await metapool.getPositionID()
  );

  const {
    feeGrowthOutside0X128: feeGrowthOutsideL0,
    feeGrowthOutside1X128: feeGrowthOutsideL1,
  } = await pool.ticks(positionLower);
  const {
    feeGrowthOutside0X128: feeGrowthOutsideU0,
    feeGrowthOutside1X128: feeGrowthOutsideU1,
  } = await pool.ticks(positionUpper);

  const {
    feeGrowthInside0LastX128,
    feeGrowthInside1LastX128,
  } = await pool.positions(await metapool.getPositionID());

  const fee0 = getCounterfactualFees(
    feeGlobal0,
    feeGrowthOutsideL0,
    feeGrowthOutsideU0,
    feeGrowthInside0LastX128,
    Number(tick),
    _liquidity,
    Number(positionLower),
    Number(positionUpper)
  );

  const fee1 = getCounterfactualFees(
    feeGlobal1,
    feeGrowthOutsideL1,
    feeGrowthOutsideU1,
    feeGrowthInside1LastX128,
    Number(tick),
    _liquidity,
    Number(positionLower),
    Number(positionUpper)
  );

  const { amount0, amount1 } = await pool.callStatic.collect(
    addresses.gUNIV3,
    positionLower,
    positionUpper,
    ethers.utils.parseEther("100000000"),
    ethers.utils.parseEther("100000000"),
    { from: addresses.gUNIV3 }
  );

  console.log("unclaimed DAI fees:", ethers.utils.formatEther(fee0.toString()));
  console.log(
    "unclaimed WETH fees:",
    ethers.utils.formatEther(fee1.toString())
  );

  console.log(ethers.utils.formatEther(amount0));
  console.log(ethers.utils.formatEther(amount1));
  console.log(ethers.utils.formatEther(tokensOwed0));
  console.log(ethers.utils.formatEther(tokensOwed1));
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
