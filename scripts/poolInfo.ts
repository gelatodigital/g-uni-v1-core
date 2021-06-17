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
  const abi = (await hre.artifacts.readArtifact("IUniswapV3Pool"))["abi"];
  const pool = new ethers.Contract(
    addresses.WethInstV3Pool,
    abi,
    signer.provider
  );

  const { tick, sqrtPriceX96 } = await pool.slot0();
  const feeGlobal0 = await pool.feeGrowthGlobal0X128();
  const feeGlobal1 = await pool.feeGrowthGlobal1X128();
  console.log("----POOL INFO----");
  console.log(
    `current tick: ${tick.toString()} (price: ${(
      1.0001 ** Number(tick)
    ).toFixed(4)} ETH)`
  );

  const { tickCumulatives } = await pool.observe([1800, 0]);
  const avgTick = tickCumulatives[1]
    .sub(tickCumulatives[0])
    .div(ethers.BigNumber.from("1800"));
  const avgPrice = 1.0001 ** Number(avgTick.toString());
  console.log(
    `five min avg tick: ${avgTick.toString()} (price: ${avgPrice.toFixed(
      4
    )} ETH)`
  );
  console.log("current sqrtPriceX96:", sqrtPriceX96.toString());
  const avgSqrtPrice = avgPrice ** 0.5;
  const twoEighty = BigNumber.from("2").pow("80");
  const avgSqrtPriceX96 = BigNumber.from(
    Math.round(avgSqrtPrice * 2 ** 16).toString()
  ).mul(twoEighty);
  console.log("five min avg sqrtPriceX96:", avgSqrtPriceX96.toString());
  const avgSqrtPrice4Percent = avgSqrtPriceX96.div("25");

  for (let i = 0; i < 2; i++) {
    console.log("");
    console.log(`----POSITION ${(i + 1).toString()}----`);
    let gelatoUniV3Pool;
    if (i == 0) {
      gelatoUniV3Pool = await ethers.getContractAt(
        "GUniPoolStatic",
        addresses.GUNIWethInst1
      );
    } else {
      gelatoUniV3Pool = await ethers.getContractAt(
        "GUniPoolStatic",
        addresses.GUNIWethInst2
      );
    }
    // eslint-disable-next-line
    const { _liquidity, tokensOwed0, tokensOwed1 } = await pool.positions(
      await gelatoUniV3Pool.getPositionID()
    );

    const positionLower = await gelatoUniV3Pool.lowerTick();
    const positionUpper = await gelatoUniV3Pool.upperTick();

    const {
      feeGrowthOutside0X128: feeGrowthOutsideL0,
      feeGrowthOutside1X128: feeGrowthOutsideL1,
    } = await pool.ticks(positionLower);
    const {
      feeGrowthOutside0X128: feeGrowthOutsideU0,
      feeGrowthOutside1X128: feeGrowthOutsideU1,
    } = await pool.ticks(positionUpper);

    const { feeGrowthInside0LastX128, feeGrowthInside1LastX128 } =
      await pool.positions(await gelatoUniV3Pool.getPositionID());

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
    const ret = await gelatoUniV3Pool.getUnderlyingBalances();
    const supply = await gelatoUniV3Pool.totalSupply();
    const lowerPrice = 1.0001 ** Number(positionLower);
    const upperPrice = 1.0001 ** Number(positionUpper);
    console.log(
      `lower tick: ${positionLower.toString()} (price: ${lowerPrice.toFixed(
        3
      )} ETH)`
    );
    console.log(
      `upper tick: ${positionUpper.toString()} (price: ${upperPrice.toFixed(
        3
      )} ETH)`
    );
    console.log("INST total:", ethers.utils.formatEther(ret[0]));
    console.log("WETH total:", ethers.utils.formatEther(ret[1]));
    console.log(
      "unclaimed INST fees:",
      ethers.utils.formatEther(fee0.add(tokensOwed0))
    );
    console.log(
      "unclaimed WETH fees:",
      ethers.utils.formatEther(fee1.add(tokensOwed1))
    );
    console.log("G-UNI total supply:", ethers.utils.formatEther(supply));
    const normalizedUnderlying0 =
      Number(ethers.utils.formatEther(ret[0])) /
      Number(ethers.utils.formatEther(supply));
    const normalizedUnderlying1 =
      Number(ethers.utils.formatEther(ret[1])) /
      Number(ethers.utils.formatEther(supply));
    console.log(
      `1 G-UNI is worth: ${normalizedUnderlying0.toFixed(2)} INST and ${Number(
        normalizedUnderlying1
      ).toFixed(6)} ETH`
    );
    console.log("");
    console.log("------executiveRebalance FUNCTION DATA-------");
    const data = gelatoUniV3Pool.interface.encodeFunctionData("executiveRebalance", [
      -52980,
      -39120,
      avgSqrtPriceX96.add(avgSqrtPrice4Percent),
      10000
    ]);
    console.log(data);
  }
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
