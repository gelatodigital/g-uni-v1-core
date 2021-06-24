import { expect } from "chai";
import { BigNumber } from "bignumber.js";
import { ethers, network } from "hardhat";
import {
  IERC20,
  IUniswapV3Factory,
  IUniswapV3Pool,
  SwapTest,
  GUniPoolStatic,
} from "../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

// eslint-disable-next-line
BigNumber.config({ EXPONENTIAL_AT: 999999, DECIMAL_PLACES: 40 });

// returns the sqrt price as a 64x96
function encodePriceSqrt(reserve1: string, reserve0: string) {
  return new BigNumber(reserve1)
    .div(reserve0)
    .sqrt()
    .multipliedBy(new BigNumber(2).pow(96))
    .integerValue(3)
    .toString();
}

function position(address: string, lowerTick: number, upperTick: number) {
  return ethers.utils.solidityKeccak256(
    ["address", "int24", "int24"],
    [address, lowerTick, upperTick]
  );
}

describe("GUniPoolStatic", function () {
  this.timeout(0);

  let uniswapFactory: IUniswapV3Factory;
  let uniswapPool: IUniswapV3Pool;

  let token0: IERC20;
  let token1: IERC20;
  let user0: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let swapTest: SwapTest;
  let gUniPoolStatic: GUniPoolStatic;
  let gelato: SignerWithAddress;
  let uniswapPoolAddress: string;

  before(async function () {
    [user0, user1, user2, gelato] = await ethers.getSigners();

    const swapTestFactory = await ethers.getContractFactory("SwapTest");
    swapTest = (await swapTestFactory.deploy()) as SwapTest;
  });

  beforeEach(async function () {
    const uniswapV3Factory = await ethers.getContractFactory(
      "UniswapV3Factory"
    );
    const uniswapDeploy = await uniswapV3Factory.deploy();
    uniswapFactory = (await ethers.getContractAt(
      "IUniswapV3Factory",
      uniswapDeploy.address
    )) as IUniswapV3Factory;

    const mockERC20Factory = await ethers.getContractFactory("MockERC20");
    token0 = (await mockERC20Factory.deploy()) as IERC20;
    token1 = (await mockERC20Factory.deploy()) as IERC20;

    await token0.approve(
      swapTest.address,
      ethers.utils.parseEther("10000000000000")
    );
    await token1.approve(
      swapTest.address,
      ethers.utils.parseEther("10000000000000")
    );

    // Sort token0 & token1 so it follows the same order as Uniswap & the GUniPoolStaticFactory
    if (
      ethers.BigNumber.from(token0.address).gt(
        ethers.BigNumber.from(token1.address)
      )
    ) {
      const tmp = token0;
      token0 = token1;
      token1 = tmp;
    }

    await uniswapFactory.createPool(token0.address, token1.address, "3000");
    uniswapPoolAddress = await uniswapFactory.getPool(
      token0.address,
      token1.address,
      "3000"
    );
    uniswapPool = (await ethers.getContractAt(
      "IUniswapV3Pool",
      uniswapPoolAddress
    )) as IUniswapV3Pool;
    await uniswapPool.initialize(encodePriceSqrt("1", "1"));

    await uniswapPool.increaseObservationCardinalityNext("5");

    const gUniPoolStaticFactory = await ethers.getContractFactory(
      "GUniPoolStatic"
    );

    gUniPoolStatic = (await gUniPoolStaticFactory.deploy(
      await gelato.getAddress()
    )) as GUniPoolStatic;

    await gUniPoolStatic.initialize(
      "G-UNI TEST POOL",
      "G-UNI",
      uniswapPoolAddress,
      5000,
      -887220,
      887220,
      await user0.getAddress()
    );
  });

  describe("Before liquidity deposited", function () {
    beforeEach(async function () {
      await token0.approve(
        gUniPoolStatic.address,
        ethers.utils.parseEther("1000000")
      );
      await token1.approve(
        gUniPoolStatic.address,
        ethers.utils.parseEther("1000000")
      );
    });

    describe("deposit", function () {
      it("Should deposit funds into GUniPoolStatic", async function () {
        const result = await gUniPoolStatic.getMintAmounts(
          ethers.utils.parseEther("1"),
          ethers.utils.parseEther("1")
        );
        await gUniPoolStatic.mint(result.mintAmount, await user0.getAddress());

        expect(await token0.balanceOf(uniswapPool.address)).to.be.gt(0);
        expect(await token1.balanceOf(uniswapPool.address)).to.be.gt(0);
        const [liquidity] = await uniswapPool.positions(
          position(gUniPoolStatic.address, -887220, 887220)
        );
        expect(liquidity).to.be.gt(0);
        const supply = await gUniPoolStatic.totalSupply();
        expect(supply).to.be.gt(0);
        const result2 = await gUniPoolStatic.getMintAmounts(
          ethers.utils.parseEther("0.5"),
          ethers.utils.parseEther("1")
        );
        await gUniPoolStatic.mint(result2.mintAmount, await user0.getAddress());
        const [liquidity2] = await uniswapPool.positions(
          position(gUniPoolStatic.address, -887220, 887220)
        );
        expect(liquidity2).to.be.gt(liquidity);

        await gUniPoolStatic.transfer(
          await user1.getAddress(),
          ethers.utils.parseEther("1")
        );
        await gUniPoolStatic
          .connect(user1)
          .approve(await user0.getAddress(), ethers.utils.parseEther("1"));
        await gUniPoolStatic
          .connect(user0)
          .transferFrom(
            await user1.getAddress(),
            await user0.getAddress(),
            ethers.utils.parseEther("1")
          );

        const decimals = await gUniPoolStatic.decimals();
        const symbol = await gUniPoolStatic.symbol();
        const name = await gUniPoolStatic.name();
        expect(symbol).to.equal("G-UNI");
        expect(decimals).to.equal(18);
        expect(name).to.equal("G-UNI TEST POOL");
      });
    });

    describe("onlyGelato", function () {
      it("should fail if not called by gelato", async function () {
        await expect(
          gUniPoolStatic
            .connect(user1)
            .rebalance(encodePriceSqrt("10", "1"), 5000, 10, token0.address)
        ).to.be.reverted;
        await expect(
          gUniPoolStatic
            .connect(user1)
            .withdrawManagerBalance(1, token0.address)
        ).to.be.reverted;
        await expect(
          gUniPoolStatic.connect(user1).withdrawGelatoBalance(1, token0.address)
        ).to.be.reverted;
      });
      it("should fail if no fees earned", async function () {
        await expect(
          gUniPoolStatic
            .connect(gelato)
            .rebalance(encodePriceSqrt("10", "1"), 5000, 10, token0.address)
        ).to.be.reverted;
        await expect(
          gUniPoolStatic
            .connect(gelato)
            .withdrawManagerBalance(1, token0.address)
        ).to.be.reverted;
        await expect(
          gUniPoolStatic
            .connect(gelato)
            .withdrawGelatoBalance(1, token0.address)
        ).to.be.reverted;
      });
    });

    describe("onlyManager", function () {
      it("should fail if not called by manager", async function () {
        await expect(
          gUniPoolStatic
            .connect(gelato)
            .updateGelatoParams(300, 5000, 5000, 5000, await user0.getAddress())
        ).to.be.reverted;

        await expect(
          gUniPoolStatic
            .connect(gelato)
            .transferOwnership(await user1.getAddress())
        ).to.be.reverted;
        await expect(gUniPoolStatic.connect(gelato).renounceOwnership()).to.be
          .reverted;
      });
    });

    describe("After liquidity deposited", function () {
      beforeEach(async function () {
        const result = await gUniPoolStatic.getMintAmounts(
          ethers.utils.parseEther("1"),
          ethers.utils.parseEther("1")
        );
        await gUniPoolStatic.mint(result.mintAmount, await user0.getAddress());
      });

      describe("withdrawal", function () {
        it("should burn LP tokens and withdraw funds", async function () {
          await gUniPoolStatic.burn(
            (await gUniPoolStatic.totalSupply()).div("2"),
            await user0.getAddress()
          );
          const [liquidity2] = await uniswapPool.positions(
            position(gUniPoolStatic.address, -887220, 887220)
          );
          expect(liquidity2).to.be.gt(0);
          expect(await gUniPoolStatic.totalSupply()).to.be.gt(0);
          expect(
            await gUniPoolStatic.balanceOf(await user0.getAddress())
          ).to.equal(ethers.utils.parseEther("0.5"));
        });
      });

      describe("after lots of balanced trading", function () {
        beforeEach(async function () {
          await swapTest.washTrade(uniswapPool.address, "500000", 100, 2);
          await swapTest.washTrade(uniswapPool.address, "500000", 100, 2);
          await swapTest.washTrade(uniswapPool.address, "500000", 100, 2);
          await swapTest.washTrade(uniswapPool.address, "500000", 100, 2);
        });

        describe("reinvest fees", function () {
          it("should redeposit fees with a rebalance", async function () {
            const [liquidityOld] = await uniswapPool.positions(
              position(gUniPoolStatic.address, -887220, 887220)
            );
            const gelatoBalanceBefore = await token1.balanceOf(
              await gelato.getAddress()
            );

            await expect(
              gUniPoolStatic
                .connect(gelato)
                .rebalance(encodePriceSqrt("1", "1"), 6000, 10, token0.address)
            ).to.be.reverted;

            const tx = await gUniPoolStatic.updateGelatoParams(
              "1000",
              "100",
              "500",
              "300",
              await user0.getAddress()
            );
            if (network.provider && user0.provider && tx.blockHash) {
              const block = await user0.provider.getBlock(tx.blockHash);
              const executionTime = block.timestamp + 300;
              await network.provider.send("evm_mine", [executionTime]);
            }

            await gUniPoolStatic
              .connect(gelato)
              .rebalance(encodePriceSqrt("1", "1.1"), 5200, 5, token1.address);

            const gelatoBalanceAfter = await token1.balanceOf(
              await gelato.getAddress()
            );
            expect(gelatoBalanceAfter).to.be.gt(gelatoBalanceBefore);
            expect(
              Number(gelatoBalanceAfter.sub(gelatoBalanceBefore))
            ).to.be.equal(5);

            const [liquidityNew] = await uniswapPool.positions(
              position(gUniPoolStatic.address, -887220, 887220)
            );
            expect(liquidityNew).to.be.gt(liquidityOld);
          });
        });

        describe("executive rebalance", function () {
          it("should change the ticks and redeposit", async function () {
            const [liquidityOld] = await uniswapPool.positions(
              position(gUniPoolStatic.address, -887220, 887220)
            );

            await expect(
              gUniPoolStatic
                .connect(gelato)
                .rebalance(
                  encodePriceSqrt("10000", "1"),
                  5000,
                  100,
                  token0.address
                )
            ).to.be.reverted;

            const tx = await gUniPoolStatic
              .connect(user0)
              .updateGelatoParams(
                "5000",
                "5000",
                "5000",
                "200",
                await user0.getAddress()
              );
            await tx.wait();
            await swapTest.washTrade(
              uniswapPool.address,
              "500000000000000000",
              100,
              2
            );
            if (network.provider && user0.provider && tx.blockHash) {
              const block = await user0.provider.getBlock(tx.blockHash);
              const executionTime = block.timestamp + 300;
              await network.provider.send("evm_mine", [executionTime]);
            }
            const lowerTickBefore = await gUniPoolStatic.lowerTick();
            const upperTickBefore = await gUniPoolStatic.upperTick();
            expect(lowerTickBefore).to.equal(-887220);
            expect(upperTickBefore).to.equal(887220);
            await gUniPoolStatic
              .connect(user0)
              .executiveRebalance(
                -443580,
                443580,
                encodePriceSqrt("1.1", "1"),
                4000
              );

            const lowerTickAfter = await gUniPoolStatic.lowerTick();
            const upperTickAfter = await gUniPoolStatic.upperTick();
            expect(lowerTickAfter).to.equal(-443580);
            expect(upperTickAfter).to.equal(443580);

            const [liquidityOldAfter] = await uniswapPool.positions(
              position(gUniPoolStatic.address, -887220, 887220)
            );
            expect(liquidityOldAfter).to.equal("0");
            expect(liquidityOldAfter).to.be.lt(liquidityOld);

            const [liquidityNew] = await uniswapPool.positions(
              position(gUniPoolStatic.address, -443580, 443580)
            );
            expect(liquidityNew).to.be.gt(liquidityOld);

            const gelatoBalance0 = await gUniPoolStatic.gelatoBalance0();
            const gelatoBalance1 = await gUniPoolStatic.gelatoBalance1();

            // console.log(gelatoBalance0.toString(), gelatoBalance1.toString());

            await gUniPoolStatic.burn(
              await gUniPoolStatic.totalSupply(),
              await user0.getAddress()
            );

            await gUniPoolStatic
              .connect(gelato)
              .withdrawManagerBalance(1, token0.address);

            const contractBalance0 = await token0.balanceOf(
              gUniPoolStatic.address
            );
            const contractBalance1 = await token1.balanceOf(
              gUniPoolStatic.address
            );
            // console.log(
            //   contractBalance0.toString(),
            //   contractBalance1.toString()
            // );

            expect(contractBalance0).to.equal(gelatoBalance0);
            expect(contractBalance1).to.equal(gelatoBalance1);
          });

          it("should receive same amounts on burn as spent on mint (if no trading)", async function () {
            const user1Address = await user1.getAddress();
            const user2Address = await user2.getAddress();
            await token0.transfer(
              user2Address,
              ethers.utils.parseEther("1000")
            );
            await token1.transfer(
              user2Address,
              ethers.utils.parseEther("1000")
            );
            await token0.transfer(
              user1Address,
              ethers.utils.parseEther("1000")
            );
            await token1.transfer(
              user1Address,
              ethers.utils.parseEther("1000")
            );
            await token0
              .connect(user1)
              .approve(gUniPoolStatic.address, ethers.constants.MaxUint256);
            await token1
              .connect(user1)
              .approve(gUniPoolStatic.address, ethers.constants.MaxUint256);
            const result = await gUniPoolStatic.getMintAmounts(
              ethers.utils.parseEther("9"),
              ethers.utils.parseEther("9")
            );
            await gUniPoolStatic
              .connect(user1)
              .mint(result.mintAmount, user1Address);
            await token0
              .connect(user2)
              .approve(gUniPoolStatic.address, ethers.constants.MaxUint256);
            await token1
              .connect(user2)
              .approve(gUniPoolStatic.address, ethers.constants.MaxUint256);
            const result2 = await gUniPoolStatic.getMintAmounts(
              ethers.utils.parseEther("10"),
              ethers.utils.parseEther("10")
            );
            await gUniPoolStatic
              .connect(user2)
              .mint(result2.mintAmount, user2Address);

            const balanceAfterMint0 = await token0.balanceOf(user2Address);
            const balanceAfterMint1 = await token0.balanceOf(user2Address);

            expect(
              ethers.utils.parseEther("1000").sub(balanceAfterMint0.toString())
            ).to.be.gt(ethers.BigNumber.from("1"));
            expect(
              ethers.utils.parseEther("1000").sub(balanceAfterMint1.toString())
            ).to.be.gt(ethers.BigNumber.from("1"));

            await gUniPoolStatic
              .connect(user2)
              .burn(await gUniPoolStatic.balanceOf(user2Address), user2Address);
            const balanceAfterBurn0 = await token0.balanceOf(user2Address);
            const balanceAfterBurn1 = await token0.balanceOf(user2Address);
            expect(
              ethers.utils.parseEther("1000").sub(balanceAfterBurn1.toString())
            ).to.be.lte(ethers.BigNumber.from("2"));
            expect(
              ethers.utils.parseEther("1000").sub(balanceAfterBurn0.toString())
            ).to.be.lte(ethers.BigNumber.from("2"));
            expect(
              ethers.utils.parseEther("1000").sub(balanceAfterBurn1.toString())
            ).to.be.gte(ethers.constants.Zero);
            expect(
              ethers.utils.parseEther("1000").sub(balanceAfterBurn0.toString())
            ).to.be.gte(ethers.constants.Zero);
          });
        });
      });

      describe("simulate price moves and deposits, prove all value is returned on burn", function () {
        it("does not get tokens stuck in contract", async function () {
          await swapTest.washTrade(
            uniswapPool.address,
            "50000000000000000000000",
            100,
            3
          );
          await swapTest.washTrade(
            uniswapPool.address,
            "50000000000000000000000",
            100,
            3
          );
          const { sqrtPriceX96 } = await uniswapPool.slot0();
          const slippagePrice = sqrtPriceX96.sub(
            sqrtPriceX96.div(ethers.BigNumber.from("25"))
          );
          await expect(
            gUniPoolStatic
              .connect(gelato)
              .rebalance(slippagePrice, 5000, 10, token0.address)
          ).to.be.reverted;

          const tx = await gUniPoolStatic
            .connect(user0)
            .updateGelatoParams(
              "5000",
              "5000",
              "5000",
              "200",
              await user0.getAddress()
            );
          if (network.provider && user0.provider && tx.blockHash) {
            const block = await user0.provider.getBlock(tx.blockHash);
            const executionTime = block.timestamp + 300;
            await network.provider.send("evm_mine", [executionTime]);
          }
          await gUniPoolStatic
            .connect(gelato)
            .rebalance(slippagePrice, 3000, 2, token0.address);

          let contractBalance0 = await token0.balanceOf(gUniPoolStatic.address);
          let contractBalance1 = await token1.balanceOf(gUniPoolStatic.address);
          // console.log(contractBalance0.toString(), contractBalance1.toString());
          await token0.transfer(await user1.getAddress(), "10000000000");
          await token1.transfer(await user1.getAddress(), "10000000000");
          await token0
            .connect(user1)
            .approve(gUniPoolStatic.address, "10000000000000");
          await token1
            .connect(user1)
            .approve(gUniPoolStatic.address, "10000000000000");
          const result = await gUniPoolStatic.getMintAmounts(1000000, 1000000);
          await gUniPoolStatic
            .connect(user1)
            .mint(result.mintAmount, await user1.getAddress());

          contractBalance0 = await token0.balanceOf(gUniPoolStatic.address);
          contractBalance1 = await token1.balanceOf(gUniPoolStatic.address);
          // console.log(contractBalance0.toString(), contractBalance1.toString());

          await swapTest.washTrade(uniswapPool.address, "50000", 100, 3);
          const tx2 = await swapTest.washTrade(
            uniswapPool.address,
            "50000",
            100,
            3
          );
          await tx2.wait();
          if (network.provider && tx2.blockHash && user0.provider) {
            const block = await user0.provider.getBlock(tx2.blockHash);
            const executionTime = block.timestamp + 300;
            await network.provider.send("evm_mine", [executionTime]);
          }
          const { sqrtPriceX96: p2 } = await uniswapPool.slot0();
          const slippagePrice2 = p2.sub(p2.div(ethers.BigNumber.from("50")));
          await gUniPoolStatic
            .connect(gelato)
            .rebalance(slippagePrice2, 9000, 1, token0.address);
          contractBalance0 = await token0.balanceOf(gUniPoolStatic.address);
          contractBalance1 = await token1.balanceOf(gUniPoolStatic.address);
          // console.log(contractBalance0.toString(), contractBalance1.toString());

          // TEST MINT/BURN should return same amount
          await token0.transfer(await user2.getAddress(), "100000000000");
          await token1.transfer(await user2.getAddress(), "100000000000");
          await token0
            .connect(user2)
            .approve(gUniPoolStatic.address, "1000000000000000");
          await token1
            .connect(user2)
            .approve(gUniPoolStatic.address, "1000000000000000");
          const preBalance0 = await token0.balanceOf(await user2.getAddress());
          const preBalance1 = await token1.balanceOf(await user2.getAddress());
          const preBalanceG = await gUniPoolStatic.balanceOf(
            await user2.getAddress()
          );
          const mintAmounts = await gUniPoolStatic.getMintAmounts(
            "90000000002",
            "90000000002"
          );

          await gUniPoolStatic
            .connect(user2)
            .mint(mintAmounts.mintAmount, await user2.getAddress());
          const intermediateBalance0 = await token0.balanceOf(
            await user2.getAddress()
          );
          const intermediateBalance1 = await token1.balanceOf(
            await user2.getAddress()
          );
          const intermediateBalanceG = await gUniPoolStatic.balanceOf(
            await user2.getAddress()
          );

          expect(preBalance0.sub(intermediateBalance0)).to.equal(
            mintAmounts.amount0
          );
          expect(preBalance1.sub(intermediateBalance1)).to.equal(
            mintAmounts.amount1
          );
          expect(intermediateBalanceG.sub(preBalanceG)).to.equal(
            mintAmounts.mintAmount
          );
          await gUniPoolStatic
            .connect(user2)
            .burn(
              await gUniPoolStatic.balanceOf(await user2.getAddress()),
              await user2.getAddress()
            );
          const postBalance0 = await token0.balanceOf(await user2.getAddress());
          const postBalance1 = await token1.balanceOf(await user2.getAddress());

          expect(preBalance0.sub(postBalance0)).to.be.lte(
            ethers.BigNumber.from("2")
          );
          expect(preBalance0.sub(postBalance0)).to.be.gte(
            ethers.constants.Zero
          );
          expect(preBalance1.sub(postBalance1)).to.be.lte(
            ethers.BigNumber.from("2")
          );
          expect(preBalance1.sub(postBalance1)).to.be.gte(
            ethers.constants.Zero
          );

          await gUniPoolStatic
            .connect(user1)
            .burn(
              await gUniPoolStatic.balanceOf(await user1.getAddress()),
              await user1.getAddress()
            );

          contractBalance0 = await token0.balanceOf(gUniPoolStatic.address);
          contractBalance1 = await token1.balanceOf(gUniPoolStatic.address);
          // console.log(contractBalance0.toString(), contractBalance1.toString());

          await gUniPoolStatic
            .connect(user0)
            .burn(await gUniPoolStatic.totalSupply(), await user0.getAddress());

          await gUniPoolStatic
            .connect(gelato)
            .withdrawGelatoBalance(1, token0.address);

          await gUniPoolStatic
            .connect(gelato)
            .withdrawManagerBalance(1, token0.address);

          contractBalance0 = await token0.balanceOf(gUniPoolStatic.address);
          contractBalance1 = await token1.balanceOf(gUniPoolStatic.address);
          // console.log(contractBalance0.toString(), contractBalance1.toString());

          expect(contractBalance0).to.equal(0);
          expect(contractBalance1).to.equal(0);
        });
      });
      describe("manager fees, withdrawals, and ownership", function () {
        it("should handle manager fees and ownership", async function () {
          for (let i = 0; i < 3; i++) {
            await swapTest.washTrade(uniswapPool.address, "50000", 100, 3);
            await swapTest.washTrade(uniswapPool.address, "50000", 100, 3);
          }
          const { sqrtPriceX96 } = await uniswapPool.slot0();
          const slippagePrice = sqrtPriceX96.sub(
            sqrtPriceX96.div(ethers.BigNumber.from("25"))
          );
          await expect(
            gUniPoolStatic
              .connect(gelato)
              .rebalance(slippagePrice, 5000, 2, token0.address)
          ).to.be.reverted;
          const tx = await gUniPoolStatic
            .connect(user0)
            .updateGelatoParams(
              "9000",
              "9000",
              "500",
              "300",
              await user1.getAddress()
            );
          await tx.wait();
          if (network.provider && tx.blockHash && user0.provider) {
            const block = await user0.provider.getBlock(tx.blockHash);
            const executionTime = block.timestamp + 300;
            await network.provider.send("evm_mine", [executionTime]);
          }
          await gUniPoolStatic
            .connect(gelato)
            .rebalance(slippagePrice, 5000, 2, token0.address);

          const treasuryBal0 = await token0.balanceOf(await user1.getAddress());
          const treasuryBal1 = await token1.balanceOf(await user1.getAddress());

          await gUniPoolStatic
            .connect(gelato)
            .withdrawManagerBalance(2, token0.address);

          const treasuryBalEnd0 = await token0.balanceOf(
            await user1.getAddress()
          );
          const treasuryBalEnd1 = await token1.balanceOf(
            await user1.getAddress()
          );

          expect(treasuryBalEnd0).to.be.gt(treasuryBal0);
          expect(treasuryBalEnd1).to.be.gt(treasuryBal1);

          const bal0End = await gUniPoolStatic.managerBalance0();
          const bal1End = await gUniPoolStatic.managerBalance1();

          expect(bal0End).to.equal(ethers.constants.Zero);
          expect(bal1End).to.equal(ethers.constants.Zero);

          const gelatoBal0 = await token0.balanceOf(await gelato.getAddress());
          const gelatoBal1 = await token1.balanceOf(await gelato.getAddress());

          await gUniPoolStatic
            .connect(gelato)
            .withdrawGelatoBalance(1, token0.address);

          const gelatoBalEnd0 = await token0.balanceOf(
            await gelato.getAddress()
          );
          const gelatoBalEnd1 = await token1.balanceOf(
            await gelato.getAddress()
          );

          expect(gelatoBalEnd0).to.be.gt(gelatoBal0);
          expect(gelatoBalEnd1).to.be.gt(gelatoBal1);

          const gelatoLeft0 = await gUniPoolStatic.gelatoBalance0();
          const gelatoLeft1 = await gUniPoolStatic.gelatoBalance1();

          expect(gelatoLeft0).to.equal(ethers.constants.Zero);
          expect(gelatoLeft1).to.equal(ethers.constants.Zero);
          const treasuryStart = await gUniPoolStatic.managerTreasury();
          expect(treasuryStart).to.equal(await user1.getAddress());
          await expect(gUniPoolStatic.connect(gelato).renounceOwnership()).to.be
            .reverted;
          const manager = await gUniPoolStatic.manager();
          expect(manager).to.equal(await user0.getAddress());
          await gUniPoolStatic
            .connect(user0)
            .transferOwnership(await user1.getAddress());
          const manager2 = await gUniPoolStatic.manager();
          expect(manager2).to.equal(await user1.getAddress());
          await gUniPoolStatic.connect(user1).renounceOwnership();
          const treasuryEnd = await gUniPoolStatic.managerTreasury();
          expect(treasuryEnd).to.equal(ethers.constants.AddressZero);
          const lastManager = await gUniPoolStatic.manager();
          expect(lastManager).to.equal(ethers.constants.AddressZero);
          const firstManager = await gUniPoolStatic.initialManager();
          expect(firstManager).to.equal(await user0.getAddress());
        });
      });
    });
  });
});
