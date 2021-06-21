/*import { expect } from "chai";
import { BigNumber } from "bignumber.js";
import { ethers, network } from "hardhat";
import {
  GUni,
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

  let token0: GUni;
  let token1: GUni;
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
    token0 = (await mockERC20Factory.deploy()) as GUni;
    token1 = (await mockERC20Factory.deploy()) as GUni;

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
      uniswapPoolAddress,
      await gelato.getAddress()
    )) as GUniPoolStatic;

    await gUniPoolStatic.initialize(-887220, 887220, await user0.getAddress());
  });

  describe("GUniPoolStatic", function () {
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
        expect(symbol).to.equal("G-UNI");
        expect(decimals).to.equal(18);
        await gUniPoolStatic.name();
      });
    });

    describe("rebalance", function () {
      it("should fail if not called by gelato", async function () {
        await expect(
          gUniPoolStatic
            .connect(user1)
            .rebalance(encodePriceSqrt("10", "1"), 5000, 10, token0.address)
        ).to.be.reverted;
      });
      it("should fail if time did not change", async function () {
        await expect(
          gUniPoolStatic
            .connect(gelato)
            .rebalance(encodePriceSqrt("10", "1"), 5000, 10, token0.address)
        ).to.be.reverted;
      });
    });

    describe("update accepted parameters", function () {
      it("should fail if not called by owner", async function () {
        await expect(
          gUniPoolStatic
            .connect(gelato)
            .updateAdminParams(
              300,
              5000,
              5000,
              5000,
              5000,
              ethers.constants.AddressZero
            )
        ).to.be.reverted;
      });
    });

    describe("with liquidity deposited", function () {
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

            const tx = await token0.approve(await user1.getAddress(), "100");
            tx.wait();
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

            const tx = await token0.approve(await user1.getAddress(), "100");
            tx.wait();
            await swapTest.washTrade(uniswapPool.address, "50000", 100, 2);
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

            let contractBalance0 = await token0.balanceOf(
              gUniPoolStatic.address
            );
            let contractBalance1 = await token1.balanceOf(
              gUniPoolStatic.address
            );
            console.log(
              contractBalance0.toString(),
              contractBalance1.toString()
            );

            await gUniPoolStatic.burn(
              await gUniPoolStatic.totalSupply(),
              await user0.getAddress()
            );
            contractBalance0 = await token0.balanceOf(gUniPoolStatic.address);
            contractBalance1 = await token1.balanceOf(gUniPoolStatic.address);
            console.log(
              contractBalance0.toString(),
              contractBalance1.toString()
            );
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
          await swapTest.washTrade(uniswapPool.address, "50000", 100, 3);
          await swapTest.washTrade(uniswapPool.address, "50000", 100, 3);
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
            .updateAdminParams(
              "200",
              "5000",
              "0",
              "5000",
              "5000",
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
          console.log(contractBalance0.toString(), contractBalance1.toString());
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
          console.log(contractBalance0.toString(), contractBalance1.toString());

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
            .rebalance(slippagePrice2, 9000, 10, token0.address);
          contractBalance0 = await token0.balanceOf(gUniPoolStatic.address);
          contractBalance1 = await token1.balanceOf(gUniPoolStatic.address);
          console.log(contractBalance0.toString(), contractBalance1.toString());

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
          console.log(contractBalance0.toString(), contractBalance1.toString());

          await gUniPoolStatic
            .connect(user0)
            .burn(await gUniPoolStatic.totalSupply(), await user0.getAddress());

          contractBalance0 = await token0.balanceOf(gUniPoolStatic.address);
          contractBalance1 = await token1.balanceOf(gUniPoolStatic.address);
          console.log(contractBalance0.toString(), contractBalance1.toString());

          expect(contractBalance0).to.equal(0);
          expect(contractBalance0).to.equal(0);
        });
      });
      describe("admin fees and withdrawals", function () {
        it("should be able to set admin fee and withdraw any accrued", async function () {
          await swapTest.washTrade(uniswapPool.address, "50000", 100, 3);
          await swapTest.washTrade(uniswapPool.address, "50000", 100, 3);
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
            .updateAdminParams(
              "200",
              "500",
              "5000",
              "9000",
              "9000",
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
            .autoWithdrawAdminBalance(2, token0.address);

          const treasuryBalEnd0 = await token0.balanceOf(
            await user1.getAddress()
          );
          const treasuryBalEnd1 = await token1.balanceOf(
            await user1.getAddress()
          );

          expect(treasuryBalEnd0).to.be.gt(treasuryBal0);
          expect(treasuryBalEnd1).to.be.gt(treasuryBal1);

          /*const bal0End = await gUniPoolStatic.adminBalanceToken0();
          const bal1End = await gUniPoolStatic.adminBalanceToken1();

          expect(bal0End).to.equal(ethers.constants.Zero);
          expect(bal1End).to.equal(ethers.constants.Zero);

          treasuryBal0 = treasuryBalEnd0;
          treasuryBal1 = treasuryBalEnd1;

          await swapTest.washTrade(uniswapPool.address, "500000", 100, 4);
          await swapTest.washTrade(uniswapPool.address, "500000", 100, 4);

          let adminBalCheck0 = await gUniPoolStatic.adminBalanceToken0();
          let adminBalCheck1 = await gUniPoolStatic.adminBalanceToken1();

          expect(adminBalCheck0).to.equal(ethers.constants.Zero);
          expect(adminBalCheck1).to.equal(ethers.constants.Zero);

          await gUniPoolStatic.withdrawAdminBalance();

          treasuryBalEnd0 = await token0.balanceOf(await user1.getAddress());
          treasuryBalEnd1 = await token1.balanceOf(await user1.getAddress());

          expect(treasuryBalEnd0).to.equal(treasuryBal0);
          expect(treasuryBalEnd1).to.equal(treasuryBal1);

          await gUniPoolStatic
            .connect(gelato)
            .rebalance(slippagePrice, 5000, 2, token0.address);

          adminBalCheck0 = await gUniPoolStatic.adminBalanceToken0();
          adminBalCheck1 = await gUniPoolStatic.adminBalanceToken1();

          expect(adminBalCheck0).to.be.gt(ethers.constants.Zero);
          expect(adminBalCheck1).to.be.gt(ethers.constants.Zero);

          await gUniPoolStatic.connect(user2).withdrawAdminBalance();

          treasuryBalEnd0 = await token0.balanceOf(await user1.getAddress());
          treasuryBalEnd1 = await token1.balanceOf(await user1.getAddress());

          expect(treasuryBalEnd0).to.be.gt(treasuryBal0);
          expect(treasuryBalEnd1).to.be.gt(treasuryBal1);
        });
      });
    });
  });
});*/
