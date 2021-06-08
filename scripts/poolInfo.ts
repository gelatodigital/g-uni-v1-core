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
  const gelatoUniV3Pool = await ethers.getContractAt(
    "GUniPoolStatic",
    addresses.GUNIV3
  );
  const abi = (await hre.artifacts.readArtifact("IUniswapV3Pool"))["abi"];
  const pool = new ethers.Contract(
    addresses.WethDaiV3Pool,
    abi,
    signer.provider
  );

  const { tick, sqrtPriceX96, observationCardinality } = await pool.slot0();
  const feeGlobal0 = await pool.feeGrowthGlobal0X128();
  const feeGlobal1 = await pool.feeGrowthGlobal1X128();
  console.log("----POOL INFO----");
  console.log(
    `current tick: ${tick.toString()} (price: $${(
      1 /
      1.0001 ** Number(tick)
    ).toFixed(2)})`
  );
  console.log("twap obs cardinality:", observationCardinality.toString());

  const { tickCumulatives } = await pool.observe([1800, 0]);
  const positionLower = await gelatoUniV3Pool.currentLowerTick();
  const positionUpper = await gelatoUniV3Pool.currentUpperTick();
  const avgTick = tickCumulatives[1]
    .sub(tickCumulatives[0])
    .div(ethers.BigNumber.from("1800"));
  const avgPrice = 1 / 1.0001 ** Number(avgTick.toString());
  console.log(
    `thirty min avg tick: ${avgTick.toString()} (price: $${avgPrice.toFixed(
      2
    )})`
  );

  console.log("");
  console.log("----POSITION INFO----");
  // eslint-disable-next-line
  const { _liquidity, tokensOwed0, tokensOwed1 } = await pool.positions(
    await gelatoUniV3Pool.getPositionID()
  );

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
  const sqrtPriceLower = BigNumber.from(
    (Math.sqrt(1.0001 ** Number(positionLower)) * 2 ** 36).toFixed(0)
  ).mul(BigNumber.from("2").pow(BigNumber.from("60")));
  const sqrtPriceUpper = BigNumber.from(
    (Math.sqrt(1.0001 ** Number(positionUpper)) * 2 ** 36).toFixed(0)
  ).mul(BigNumber.from("2").pow(BigNumber.from("60")));
  const { amount0, amount1 } = await gelatoUniV3Pool.getAmountsForLiquidity(
    sqrtPriceX96,
    sqrtPriceLower,
    sqrtPriceUpper,
    _liquidity
  );

  const weth = await ethers.getContractAt(
    ["function balanceOf(address) external view returns(uint256)"],
    addresses.WETH,
    signer
  );
  const dai = await ethers.getContractAt(
    ["function balanceOf(address) external view returns(uint256)"],
    addresses.DAI,
    signer
  );

  const balanceWeth = await weth.balanceOf(gelatoUniV3Pool.address);
  const balanceDai = await dai.balanceOf(gelatoUniV3Pool.address);
  const lowerPrice = 1 / 1.0001 ** Number(positionLower);
  const upperPrice = 1 / 1.0001 ** Number(positionUpper);
  console.log(
    `lower tick: ${positionLower.toString()} (price: $${lowerPrice.toFixed(2)})`
  );
  console.log(
    `upper tick: ${positionUpper.toString()} (price: $${upperPrice.toFixed(2)})`
  );
  console.log("DAI invested:", ethers.utils.formatEther(amount0));
  console.log("WETH invested:", ethers.utils.formatEther(amount1));
  console.log(
    "unclaimed DAI fees:",
    ethers.utils.formatEther(fee0.add(tokensOwed0))
  );
  console.log(
    "unclaimed WETH fees:",
    ethers.utils.formatEther(fee1.add(tokensOwed1))
  );
  console.log("DAI uninvested:", ethers.utils.formatEther(balanceDai));
  console.log("WETH uninvested:", ethers.utils.formatEther(balanceWeth));
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
