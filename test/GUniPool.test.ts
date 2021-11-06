import { expect } from "chai";
import { ethers, network } from "hardhat";
import {
  IUniswapV3Pool,
  GUniPool,
  GUniFactory,
  UniswapV3Helpers,
  IERC20,
} from "../typechain";
import {getAddresses} from "../src/addresses";

const addresses = getAddresses("mainnet");
const manager = "0x0D8410643ae7a4d833C7219E5C6faDfa5Ce912CD";
const X96 = ethers.BigNumber.from("2").pow(ethers.BigNumber.from("96"));

describe("GUniPool", function () {
  this.timeout(0);

  let factory: GUniFactory;
  let pool: GUniPool;
  let uniswapPool: IUniswapV3Pool;
  let helpers: UniswapV3Helpers;
  let token0: IERC20;
  let token1: IERC20;

  before(async function () {
    factory = ((await ethers.getContractAt(
      "GUniFactory",
      addresses.GUniFactory
    )) as unknown) as GUniFactory;
    const pools = await factory.getPools(manager);
    expect(pools.length).to.equal(1);

    pool = ((await ethers.getContractAt("GUniPool", pools[0])) as unknown) as GUniPool;
    helpers = ((await ethers.getContractAt("UniswapV3Helpers", "0xFbd0B8D8016b9f908fC9652895c26C5a4994fE36")) as unknown) as UniswapV3Helpers;
    uniswapPool = ((await ethers.getContractAt("IUniswapV3Pool", await pool.pool())) as unknown) as IUniswapV3Pool;
    token0 = ((await ethers.getContractAt("IERC20", await pool.token0())) as unknown) as IERC20;
    token1 = ((await ethers.getContractAt("IERC20", await pool.token1())) as unknown) as IERC20;

    const [signer] = await ethers.getSigners();
    await signer.sendTransaction({
      value: ethers.utils.parseEther("100"),
      to: manager
    });
  });

  it("executive rebalances", async function () {
    // read relevant values
    const {sqrtPriceX96, tick} = await uniswapPool.slot0();
    const tickSpacing = await uniswapPool.tickSpacing();
    const currentLowerTick = await pool.lowerTick();
    const currentUpperTick = await pool.upperTick();
    const {amount0Current, amount1Current} = await pool.getUnderlyingBalances();

    // validate pool is currently in range
    expect(tick).to.be.gt(currentLowerTick);
    expect(tick).to.be.lt(currentUpperTick);

    // shift ticks
    const newLowerTick = currentLowerTick + 2*tickSpacing;
    const newUpperTick = currentUpperTick + 2*tickSpacing;

    // compute maximum liquidity at new ticks 
    const liquidity = await helpers["getLiquidityForAmounts(uint160,int24,int24,uint256,uint256)"](
      sqrtPriceX96,
      newLowerTick,
      newUpperTick,
      amount0Current,
      amount1Current
    );
    
    // compute total maximum deposit at new ticks
    const {amount0, amount1} = await helpers["getAmountsForLiquidity(uint160,int24,int24,uint128)"](
      sqrtPriceX96,
      newLowerTick,
      newUpperTick,
      liquidity
    );

    // compute leftover, one token's leftover should be 0 or very close to 0.
    const leftover0 = amount0Current.sub(amount0);
    const leftover1 = amount1Current.sub(amount1);
    const bpsLeftover0 = leftover0.mul(10000).div(amount0Current);
    const bpsLeftover1 = leftover1.mul(10000).div(amount1Current);
    let zeroForOne: boolean;
    if (bpsLeftover0 > bpsLeftover1) {
      zeroForOne = true;
    } else {
      zeroForOne = false;
    }

    // compute proportion of leftover to swap
    const priceX96 = sqrtPriceX96.mul(sqrtPriceX96).div(X96); // square the sqrtPriceX96
    const amount0In1 = amount0.mul(priceX96).div(X96); // amount0 converted to a token1 amount (if price is given by sqrtPriceX96)
    const bps0 = amount0In1.mul(10000).div(amount1.add(amount0In1)); // proportion of token0 total value to token1 total value in Basis Points
    let swapAmountBPS: any;
    if (zeroForOne) {
      swapAmountBPS = ethers.BigNumber.from(10000).sub(bps0);
    } else {
      swapAmountBPS = bps0;
    }

    // compute slippage parameter
    const twoPercentSqrtPrice = sqrtPriceX96.div(50);
    let sqrtThreshold: any;
    if (zeroForOne) {
      sqrtThreshold = sqrtPriceX96.sub(twoPercentSqrtPrice); // if swapping zeroForOne, slightly less than sqrtPriceX96
    } else {
      sqrtThreshold = sqrtPriceX96.add(twoPercentSqrtPrice); // if swapping one-for-zero, slightly more than sqrtPriceX96
    }

    // impersonate manager account
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [manager],
    });
    const managerSigner = await ethers.provider.getSigner(manager);

    // manager account performs rebalance    
    await pool.connect(managerSigner).executiveRebalance(
      newLowerTick,
      newUpperTick,
      sqrtThreshold,
      swapAmountBPS,
      zeroForOne
    );
    
    // check params used (how much was 'leftover' e.g. not able to be deposited)
    const balance0 = await token0.balanceOf(pool.address);
    const balance1 = await token1.balanceOf(pool.address);
    const gelatoBalance0 = await pool.gelatoBalance0();
    const gelatoBalance1 = await pool.gelatoBalance1();

    console.log("leftover after rebalance:");
    console.log(ethers.utils.formatUnits(balance0.sub(gelatoBalance0), "18"), "UDT");
    console.log(ethers.utils.formatUnits(balance1.sub(gelatoBalance1), "18"), "WETH");
  });
});
