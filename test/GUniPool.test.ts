import { expect } from "chai";
import { ethers, network } from "hardhat";
import {
  IUniswapV3Pool,
  GUniPool,
  INonfungiblePositionManager,
  SwapTest,
  UniswapV3Helpers,
  IERC20,
} from "../typechain";
import {getAddresses} from "../src/addresses";
import { BigNumber } from 'ethers'

const addresses = getAddresses("mainnet");
const manager = "0xeD5cF41b0fD6A3C564c17eE34d9D26Eafc30619b";
const POOL = "0xae666F497e3b03415503785df36f795e6D91d4b3";
const HELPERS = "0xFbd0B8D8016b9f908fC9652895c26C5a4994fE36";
const X96 = ethers.BigNumber.from("2").pow(ethers.BigNumber.from("96"));
const WAD = ethers.BigNumber.from("10").pow(ethers.BigNumber.from("18"));
const GELHolder = "0x054BA12713290eF5B9236E55944713c0Edeb4Cf4";

const formatToken18 = (amount: BigNumber) => {
  const v = Number(ethers.utils.formatEther(amount)).toFixed(3)
  return Number(v).toLocaleString('en-US');
}

describe("GUniPool", function () {
  this.timeout(0);

  let pool: GUniPool;
  let uniswapPool: IUniswapV3Pool;
  let helpers: UniswapV3Helpers;
  let token0: IERC20;
  let token1: IERC20;
  let weth: IERC20;
  let positions: INonfungiblePositionManager;
  let swapper: SwapTest;

  before(async function () {
    pool = ((await ethers.getContractAt("GUniPool", POOL)) as unknown) as GUniPool;
    helpers = ((await ethers.getContractAt("UniswapV3Helpers", HELPERS)) as unknown) as UniswapV3Helpers;
    uniswapPool = ((await ethers.getContractAt("IUniswapV3Pool", await pool.pool())) as unknown) as IUniswapV3Pool;
    token0 = ((await ethers.getContractAt("IERC20", await pool.token0())) as unknown) as IERC20;
    token1 = ((await ethers.getContractAt("IERC20", await pool.token1())) as unknown) as IERC20;
    weth = ((await ethers.getContractAt("IERC20", addresses.WETH)) as unknown) as IERC20;
    positions = ((await ethers.getContractAt("INonfungiblePositionManager", "0xC36442b4a4522E871399CD717aBDD847Ab11FE88")) as unknown) as INonfungiblePositionManager;
    const swapTestFactory = await ethers.getContractFactory("SwapTest");
    swapper = ((await swapTestFactory.deploy()) as unknown) as SwapTest;
    const [signer] = await ethers.getSigners();
    await signer.sendTransaction({
      value: ethers.utils.parseEther("100"),
      to: manager
    });
    await signer.sendTransaction({
      value: ethers.utils.parseEther("100"),
      to: GELHolder
    });
  });

  it("executive rebalances", async function () {
    // impersonate manager account
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [GELHolder],
    });
    const gelSigner = await ethers.provider.getSigner(GELHolder);
    // read relevant values
    let {sqrtPriceX96: sqrtPrice, tick: currentTick} = await uniswapPool.slot0();
    let currentLowerTick = await pool.lowerTick();
    let currentUpperTick = await pool.upperTick();
    let {amount0Current: amount0Init, amount1Current: amount1Init} = await pool.getUnderlyingBalances();
    let totalInToken1 = amount1Init.add(sqrtPrice.mul(sqrtPrice).mul(amount0Init).div(X96).div(X96))
    let currentETHPrice = 2900
    console.log("---- total holdings ----")
    console.log(formatToken18(amount0Init), "GEL")
    console.log(formatToken18(amount1Init), "ETH")
    console.log(formatToken18(totalInToken1), "Gross holding in ETH")
    console.log((Number(formatToken18(totalInToken1))*currentETHPrice).toLocaleString('en-US'), "Gross holding in USD")
    console.log("----- current ticks -----")
    console.log("lower tick:", currentLowerTick)
    console.log("upper tick:", currentUpperTick)
    console.log(1.0001**Number(currentLowerTick), "lower price ETH per GEL")
    console.log(1.0001**Number(currentUpperTick), "upper price ETH per GEL")
    console.log(1.0001**Number(currentLowerTick)*currentETHPrice, "lower price USD per GEL")
    console.log(1.0001**Number(currentUpperTick)*currentETHPrice, "upper price USD per GEL")

    // validate pool is currently in range
    expect(currentTick).to.be.gt(currentLowerTick);
    expect(currentTick).to.be.lt(currentUpperTick);

    const newLowerTick = -90000
    const newUpperTick = -76400

    // test slippage
    let wethBalanceBefore = await weth.balanceOf(GELHolder);
    let gelBalanceBefore = await token0.balanceOf(GELHolder);
    await token0.connect(gelSigner).approve(swapper.address, ethers.utils.parseEther("100000"))
    let thresh = sqrtPrice.sub(sqrtPrice.div(2));
    await swapper.connect(gelSigner).getSwapResult(
      uniswapPool.address,
      true,
      ethers.utils.parseEther("100000"),
      thresh
    );
    let wethBalanceAfter = await weth.balanceOf(GELHolder);
    let gelBalanceAfter = await token0.balanceOf(GELHolder);
    console.log("---- SLIPPAGE CHECK ----")
    console.log(`swap ${ethers.utils.formatEther(gelBalanceBefore.sub(gelBalanceAfter))} GEL`)
    //console.log(`for ${ethers.utils.formatEther(wethBalanceAfter.sub(wethBalanceBefore))} WETH`)
    
    let {sqrtPriceX96: sqrtPriceAfterTrade, tick: tickAfterTrade} = await uniswapPool.slot0();
    let priceAfterTrade = sqrtPriceAfterTrade.mul(sqrtPriceAfterTrade).div(X96);
    let price = sqrtPrice.mul(sqrtPrice).div(X96)
    let preprice = 1/(1.0001**currentTick);
    let postprice = 1/(1.0001**tickAfterTrade);
    console.log(`Slippage: ${Number(priceAfterTrade.sub(price).mul(10000).div(price).toString())*100/10000} %`)
    console.log("----               ----")

    await weth.connect(gelSigner).approve(swapper.address, wethBalanceAfter.sub(wethBalanceBefore))
    const thresh2 = sqrtPrice.add(sqrtPrice.div(2));
    await swapper.connect(gelSigner).getSwapResult(
      uniswapPool.address,
      false,
      wethBalanceAfter.sub(wethBalanceBefore),
      thresh2
    );


    // compute maximum liquidity at new ticks 
    const liquidity = await helpers["getLiquidityForAmounts(uint160,int24,int24,uint256,uint256)"](
      sqrtPrice,
      newLowerTick,
      newUpperTick,
      amount0Init,
      amount1Init
    );
    
    // compute total maximum deposit at new ticks
    const {amount0, amount1} = await helpers["getAmountsForLiquidity(uint160,int24,int24,uint128)"](
      sqrtPrice,
      newLowerTick,
      newUpperTick,
      liquidity
    );

    // compute leftover, one token's leftover should be 0 or very close to 0.
    const leftover0 = amount0Init.sub(amount0);
    const leftover1 = amount1Init.sub(amount1);
    const bpsLeftover0 = leftover0.mul(10000).div(amount0Init);
    const bpsLeftover1 = leftover1.mul(10000).div(amount1Init);
    let zeroForOne: boolean;
    if (bpsLeftover0 > bpsLeftover1) {
      zeroForOne = true;
    } else {
      zeroForOne = false;
    }

    // compute proportion of leftover to swap
    const priceX96 = sqrtPrice.mul(sqrtPrice).div(X96); // square the sqrtPriceX96
    const amount0In1 = amount0.mul(priceX96).div(X96); // amount0 converted to a token1 amount (if price is given by sqrtPriceX96)
    const bps0 = amount0In1.mul(10000).div(amount1.add(amount0In1)); // proportion of token0 total value to token1 total value in Basis Points
    let swapAmountBPS: any;
    let swapAmountExpected: any;
    if (zeroForOne) {
      swapAmountBPS = ethers.BigNumber.from(10000).sub(bps0).sub(100);
      swapAmountExpected = swapAmountBPS.mul(leftover0).div(10000)
    } else {
      swapAmountBPS = bps0.sub(100)
      swapAmountExpected = swapAmountBPS.mul(leftover1).div(10000)
    }

    console.log("TARGET SWAP AMOUNT:", ethers.utils.formatEther(swapAmountExpected), `${zeroForOne ? "GEL" : "ETH"}`);

    // compute slippage parameter
    const tenPercentSqrtPrice = sqrtPrice.div(10);
    let sqrtThreshold: any;
    if (zeroForOne) {
      sqrtThreshold = sqrtPrice.sub(tenPercentSqrtPrice); // if swapping zeroForOne, slightly less than sqrtPriceX96
    } else {
      sqrtThreshold = sqrtPrice.add(tenPercentSqrtPrice); // if swapping one-for-zero, slightly more than sqrtPriceX96
    }

    // addNewRangeOrder

    let rangeOrderLowerTick = currentTick;
    while (rangeOrderLowerTick % 200 != 0) {
      rangeOrderLowerTick++
    }
    let rangeOrderUpperTick = rangeOrderLowerTick+200;
    await token0.connect(gelSigner).approve(positions.address, ethers.utils.parseEther("250000"))
    const {tokenId} = await positions.connect(gelSigner).callStatic.mint(
      {
        token0: token0.address,
        token1: token1.address,
        fee: 10000,
        tickLower: rangeOrderLowerTick,
        tickUpper: rangeOrderUpperTick,
        amount0Desired:  ethers.utils.parseEther("250000"),
        amount1Desired: 0,
        amount0Min: 0,
        amount1Min: 0,
        recipient: GELHolder,
        deadline: 9999999999999
      }
    );
    await positions.connect(gelSigner).mint(
      {
        token0: token0.address,
        token1: token1.address,
        fee: 10000,
        tickLower: rangeOrderLowerTick,
        tickUpper: rangeOrderUpperTick,
        amount0Desired:  ethers.utils.parseEther("250000"),
        amount1Desired: 0,
        amount0Min: 0,
        amount1Min: 0,
        recipient: GELHolder,
        deadline: 9999999999999
      }
    );
    const {liquidity: liq} = await positions.positions(tokenId);

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

    await positions.connect(gelSigner).decreaseLiquidity(
      {
        tokenId: tokenId,
        liquidity: liq,
        amount0Min: 0,
        amount1Min: 0,
        deadline: 999999999999
      }
    );
    
    // check params used (how much was 'leftover' e.g. not able to be deposited)
    const balance0 = await token0.balanceOf(pool.address);
    const balance1 = await token1.balanceOf(pool.address);
    const gelatoBalance0 = await pool.gelatoBalance0();
    const gelatoBalance1 = await pool.gelatoBalance1();

    console.log("leftover after rebalance:");
    console.log(ethers.utils.formatUnits(balance0.sub(gelatoBalance0), "18"), "GEL");
    console.log(ethers.utils.formatUnits(balance1.sub(gelatoBalance1), "18"), "WETH");

    // read relevant values
    const {sqrtPriceX96, tick} = await uniswapPool.slot0();
    sqrtPrice = sqrtPriceX96;
    currentTick = tick;
    currentLowerTick = await pool.lowerTick();
    currentUpperTick = await pool.upperTick();
    const {amount0Current, amount1Current} = await pool.getUnderlyingBalances();
    amount0Init = amount0Current
    amount1Init = amount1Current

    totalInToken1 = amount1Init.add(sqrtPrice.mul(sqrtPrice).mul(amount0Init).div(X96).div(X96))
    currentETHPrice = 2900
    console.log("---- total holdings ----")
    console.log(formatToken18(amount0Init), "GEL")
    console.log(formatToken18(amount1Init), "ETH")
    console.log(formatToken18(totalInToken1), "Gross holding in ETH")
    console.log((Number(formatToken18(totalInToken1))*currentETHPrice).toLocaleString('en-US'), "Gross holding in USD")
    console.log("----- current ticks -----")
    console.log("lower tick:", currentLowerTick)
    console.log("upper tick:", currentUpperTick)
    console.log(1.0001**Number(currentLowerTick), "lower price ETH per GEL")
    console.log(1.0001**Number(currentUpperTick), "upper price ETH per GEL")
    console.log(1.0001**Number(currentLowerTick)*currentETHPrice, "lower price USD per GEL")
    console.log(1.0001**Number(currentUpperTick)*currentETHPrice, "upper price USD per GEL")
    // test slippage
    wethBalanceBefore = await weth.balanceOf(GELHolder);
    gelBalanceBefore = await token0.balanceOf(GELHolder);
    await token0.connect(gelSigner).approve(swapper.address, ethers.utils.parseEther("100000"))
    thresh = sqrtPrice.sub(sqrtPrice.div(2));
    await swapper.connect(gelSigner).getSwapResult(
      uniswapPool.address,
      true,
      ethers.utils.parseEther("100000"),
      thresh
    );
    wethBalanceAfter = await weth.balanceOf(GELHolder);
    gelBalanceAfter = await token0.balanceOf(GELHolder);
    console.log("---- SLIPPAGE CHECK ----")
    console.log(`swap ${ethers.utils.formatEther(gelBalanceBefore.sub(gelBalanceAfter))} GEL`)
    //console.log(`for ${ethers.utils.formatEther(wethBalanceAfter.sub(wethBalanceBefore))} WETH`)
    
    let {sqrtPriceX96: sqrtPriceAfterTrade2, tick: tickAfterTrade2} = await uniswapPool.slot0();
    priceAfterTrade = sqrtPriceAfterTrade2.mul(sqrtPriceAfterTrade2).div(X96);
    price = sqrtPrice.mul(sqrtPrice).div(X96)
    preprice = 1/(1.0001**currentTick);
    postprice = 1/(1.0001**tickAfterTrade2);
    console.log(`Slippage: ${Number(priceAfterTrade.sub(price).mul(10000).div(price).toString())*100/10000} %`)
    console.log("----               ----")
  });
});
