import { expect } from "chai";
import { BigNumber } from "bignumber.js";
import { ethers, network } from "hardhat";
import {
  GUNIV3,
  IUniswapV3Factory,
  IUniswapV3Pool,
  SwapTest,
  GelatoUniV3Pool,
} from "../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

/* eslint-disable-next-line */
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

describe("GelatoUniV3Pools", function () {
  this.timeout(0);

  let uniswapFactory: IUniswapV3Factory;
  let uniswapPool: IUniswapV3Pool;

  let token0: GUNIV3;
  let token1: GUNIV3;
  let user0: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let swapTest: SwapTest;
  let gelatoUniV3Pool: GelatoUniV3Pool;
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
    token0 = (await mockERC20Factory.deploy()) as GUNIV3;
    token1 = (await mockERC20Factory.deploy()) as GUNIV3;

    await token0.approve(
      swapTest.address,
      ethers.utils.parseEther("10000000000000")
    );
    await token1.approve(
      swapTest.address,
      ethers.utils.parseEther("10000000000000")
    );

    // Sort token0 & token1 so it follows the same order as Uniswap & the GelatoUniV3PoolFactory
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

    const gelatoUniV3PoolFactory = await ethers.getContractFactory(
      "GelatoUniV3Pool"
    );
    gelatoUniV3Pool = (await gelatoUniV3PoolFactory.deploy(
      uniswapPoolAddress,
      await gelato.getAddress()
    )) as GelatoUniV3Pool;

    await gelatoUniV3Pool.initialize(
      ethers.utils.parseEther("20000"),
      -887220,
      887220,
      await user0.getAddress()
    );
  });

  describe("GelatoUniV3Pool", function () {
    beforeEach(async function () {
      await token0.approve(
        gelatoUniV3Pool.address,
        ethers.utils.parseEther("1000000")
      );
      await token1.approve(
        gelatoUniV3Pool.address,
        ethers.utils.parseEther("1000000")
      );
    });

    describe("deposits", function () {
      it("Should deposit funds into a gelatoUniV3Pool", async function () {
        await gelatoUniV3Pool.mint("1000");

        expect(await token0.balanceOf(uniswapPool.address)).to.gt(0);
        expect(await token1.balanceOf(uniswapPool.address)).to.gt(0);
        const [liquidity] = await uniswapPool.positions(
          position(gelatoUniV3Pool.address, -887220, 887220)
        );
        expect(liquidity).to.equal("1000");
        expect(await gelatoUniV3Pool.totalSupply()).to.equal("1000");
        expect(
          await gelatoUniV3Pool.balanceOf(await user0.getAddress())
        ).to.equal("1000");

        await gelatoUniV3Pool.mint("500");

        const [liquidity2] = await uniswapPool.positions(
          position(gelatoUniV3Pool.address, -887220, 887220)
        );
        expect(liquidity2).to.equal("1500");
        expect(await gelatoUniV3Pool.totalSupply()).to.equal("1500");
        expect(
          await gelatoUniV3Pool.balanceOf(await user0.getAddress())
        ).to.equal("1500");
      });
    });

    describe("rebalance", function () {
      it("should fail if not called by gelato", async function () {
        await expect(
          gelatoUniV3Pool
            .connect(user1)
            .rebalance(
              -443610,
              443610,
              encodePriceSqrt("10", "1"),
              5000,
              10,
              token0.address
            )
        ).to.be.reverted;
      });
      it("should fail if time did not change", async function () {
        await expect(
          gelatoUniV3Pool
            .connect(gelato)
            .rebalance(
              -443610,
              443610,
              encodePriceSqrt("10", "1"),
              5000,
              10,
              token0.address
            )
        ).to.be.reverted;
      });
    });

    describe("update accepted parameters", function () {
      it("should fail if not called by owner", async function () {
        await expect(
          gelatoUniV3Pool
            .connect(gelato)
            .updateMetaParams(
              ethers.constants.MaxUint256,
              "42000",
              "60",
              "7000",
              "300",
              "3"
            )
        ).to.be.reverted;
      });
    });

    describe("with liquidity deposited", function () {
      beforeEach(async function () {
        await gelatoUniV3Pool.mint(1000000);
      });

      describe("withdrawal", function () {
        it("should burn LP tokens and withdraw funds", async function () {
          await gelatoUniV3Pool.burn(6000);
          const [liquidity2] = await uniswapPool.positions(
            position(gelatoUniV3Pool.address, -887220, 887220)
          );
          expect(liquidity2).to.equal((1000000 - 6000).toString());
          expect(await gelatoUniV3Pool.totalSupply()).to.equal(
            (1000000 - 6000).toString()
          );
          expect(
            await gelatoUniV3Pool.balanceOf(await user0.getAddress())
          ).to.equal((1000000 - 6000).toString());
        });
      });

      describe("after lots of balanced trading", function () {
        beforeEach(async function () {
          await swapTest.washTrade(uniswapPool.address, "5000", 100, 2);
          await swapTest.washTrade(uniswapPool.address, "5000", 100, 2);
        });

        describe("reinvest fees", function () {
          it("should redeposit fees with a rebalance", async function () {
            const [liquidityOld] = await uniswapPool.positions(
              position(gelatoUniV3Pool.address, -887220, 887220)
            );
            const gelatoBalanceBefore = await token0.balanceOf(
              await gelato.getAddress()
            );

            await expect(
              gelatoUniV3Pool
                .connect(gelato)
                .rebalance(
                  -887220,
                  887220,
                  encodePriceSqrt("1", "1"),
                  6000,
                  100,
                  token0.address
                )
            ).to.be.reverted;

            const tx = await gelatoUniV3Pool
              .connect(user0)
              .updateMetaParams(
                ethers.constants.MaxUint256,
                "300",
                "60",
                "1000000",
                "300",
                "5"
              );
            await tx.wait();
            if (network.provider && user0.provider && tx.blockHash) {
              const block = await user0.provider.getBlock(tx.blockHash);
              const executionTime = block.timestamp + 300;
              await network.provider.send("evm_mine", [executionTime]);
            }

            await expect(
              gelatoUniV3Pool
                .connect(gelato)
                .rebalance(
                  -887220,
                  887220,
                  encodePriceSqrt("100000", "1"),
                  6000,
                  100,
                  token0.address
                )
            ).to.be.reverted;

            await gelatoUniV3Pool
              .connect(gelato)
              .rebalance(
                -887220,
                887220,
                encodePriceSqrt("1.1", "1"),
                5000,
                100,
                token0.address
              );

            const gelatoBalanceAfter = await token0.balanceOf(
              await gelato.getAddress()
            );
            expect(gelatoBalanceAfter).to.be.gt(gelatoBalanceBefore);
            expect(
              Number(gelatoBalanceAfter.sub(gelatoBalanceBefore))
            ).to.be.equal(100);

            const [liquidityNew] = await uniswapPool.positions(
              position(gelatoUniV3Pool.address, -887220, 887220)
            );
            expect(liquidityNew).to.be.gt(liquidityOld);
          });
        });

        describe("rebalance", function () {
          it("should change the ticks and rebalance", async function () {
            const [liquidityOld] = await uniswapPool.positions(
              position(gelatoUniV3Pool.address, -887220, 887220)
            );
            const gelatoBalanceBefore = await token0.balanceOf(
              await gelato.getAddress()
            );

            await expect(
              gelatoUniV3Pool
                .connect(gelato)
                .rebalance(
                  -443580,
                  443580,
                  encodePriceSqrt("10000", "1"),
                  5000,
                  100,
                  token0.address
                )
            ).to.be.reverted;

            const tx = await gelatoUniV3Pool
              .connect(user0)
              .updateMetaParams(
                ethers.constants.MaxUint256,
                "300",
                "60",
                "1000000",
                "300",
                "5"
              );
            await tx.wait();
            if (network.provider && tx.blockHash && user0.provider) {
              const block = await user0.provider.getBlock(tx.blockHash);
              const executionTime = block.timestamp + 300;
              await network.provider.send("evm_mine", [executionTime]);
            }

            await gelatoUniV3Pool
              .connect(gelato)
              .rebalance(
                -443580,
                443580,
                encodePriceSqrt("1.1", "1"),
                4000,
                100,
                token0.address
              );

            const gelatoBalanceAfter = await token0.balanceOf(
              await gelato.getAddress()
            );
            expect(gelatoBalanceAfter).to.be.gt(gelatoBalanceBefore);
            expect(
              Number(gelatoBalanceAfter.sub(gelatoBalanceBefore))
            ).to.be.equal(100);

            const [liquidityOldAfter] = await uniswapPool.positions(
              position(gelatoUniV3Pool.address, -887220, 887220)
            );
            expect(liquidityOldAfter).to.equal("0");
            expect(liquidityOldAfter).to.be.lt(liquidityOld);

            const [liquidityNew] = await uniswapPool.positions(
              position(gelatoUniV3Pool.address, -443580, 443580)
            );
            expect(liquidityNew).to.be.gt(liquidityOld);

            let contractBalance0 = await token0.balanceOf(
              gelatoUniV3Pool.address
            );
            let contractBalance1 = await token1.balanceOf(
              gelatoUniV3Pool.address
            );
            console.log(
              contractBalance0.toString(),
              contractBalance1.toString()
            );

            await gelatoUniV3Pool.burn(await gelatoUniV3Pool.totalSupply());
            contractBalance0 = await token0.balanceOf(gelatoUniV3Pool.address);
            contractBalance1 = await token1.balanceOf(gelatoUniV3Pool.address);
            console.log(
              contractBalance0.toString(),
              contractBalance1.toString()
            );
          });

          it("mint/burn without trading should result in same amounts", async function () {
            await token0.transfer(
              await user2.getAddress(),
              ethers.utils.parseEther("1000")
            );
            await token1.transfer(
              await user2.getAddress(),
              ethers.utils.parseEther("1000")
            );
            await token0.transfer(
              await user1.getAddress(),
              ethers.utils.parseEther("1000")
            );
            await token1.transfer(
              await user1.getAddress(),
              ethers.utils.parseEther("1000")
            );
            await token0
              .connect(user1)
              .approve(gelatoUniV3Pool.address, ethers.constants.MaxUint256);
            await token1
              .connect(user1)
              .approve(gelatoUniV3Pool.address, ethers.constants.MaxUint256);
            await gelatoUniV3Pool
              .connect(user1)
              .mint(ethers.utils.parseEther("9"));
            await token0
              .connect(user2)
              .approve(gelatoUniV3Pool.address, ethers.constants.MaxUint256);
            await token1
              .connect(user2)
              .approve(gelatoUniV3Pool.address, ethers.constants.MaxUint256);
            await gelatoUniV3Pool
              .connect(user2)
              .mint(ethers.utils.parseEther("10"));

            const balanceAfterMint0 = await token0.balanceOf(
              await user2.getAddress()
            );
            const balanceAfterMint1 = await token0.balanceOf(
              await user2.getAddress()
            );

            expect(
              ethers.utils.parseEther("1000").sub(balanceAfterMint0.toString())
            ).to.be.gt(ethers.BigNumber.from("1"));
            expect(
              ethers.utils.parseEther("1000").sub(balanceAfterMint1.toString())
            ).to.be.gt(ethers.BigNumber.from("1"));

            await gelatoUniV3Pool
              .connect(user2)
              .burn(await gelatoUniV3Pool.balanceOf(await user2.getAddress()));
            const balanceAfterBurn0 = await token0.balanceOf(
              await user2.getAddress()
            );
            const balanceAfterBurn1 = await token0.balanceOf(
              await user2.getAddress()
            );
            expect(
              ethers.utils.parseEther("1000").sub(balanceAfterBurn1.toString())
            ).to.be.lte(ethers.BigNumber.from("1"));
            expect(
              ethers.utils.parseEther("1000").sub(balanceAfterBurn0.toString())
            ).to.be.lte(ethers.BigNumber.from("1"));
          });
        });
      });

      describe("simulate price moves and deposits, prove all value is returned on burn", function () {
        it("does not get tokens stuck in contract", async function () {
          await swapTest.washTrade(uniswapPool.address, "50000", 100, 3);
          await swapTest.washTrade(uniswapPool.address, "50000", 100, 3);
          const { sqrtPriceX96 } = await uniswapPool.slot0();
          const slippagePrice = sqrtPriceX96.add(
            sqrtPriceX96.div(ethers.BigNumber.from("100"))
          );
          await expect(
            gelatoUniV3Pool
              .connect(gelato)
              .rebalance(
                -443580,
                443580,
                slippagePrice,
                5000,
                100,
                token0.address
              )
          ).to.be.reverted;

          const tx = await gelatoUniV3Pool
            .connect(user0)
            .updateMetaParams(
              ethers.constants.MaxUint256,
              "300",
              "60",
              "1000000",
              "300",
              "5"
            );
          await tx.wait();
          if (network.provider && tx.blockHash && user0.provider) {
            const block = await user0.provider.getBlock(tx.blockHash);
            const executionTime = block.timestamp + 300;
            await network.provider.send("evm_mine", [executionTime]);
          }

          await gelatoUniV3Pool
            .connect(gelato)
            .rebalance(
              -443580,
              443580,
              slippagePrice,
              4000,
              100,
              token0.address
            );

          let contractBalance0 = await token0.balanceOf(
            gelatoUniV3Pool.address
          );
          let contractBalance1 = await token1.balanceOf(
            gelatoUniV3Pool.address
          );
          console.log(contractBalance0.toString(), contractBalance1.toString());
          await token0.transfer(await user1.getAddress(), "10000000000");
          await token1.transfer(await user1.getAddress(), "10000000000");
          await token0
            .connect(user1)
            .approve(gelatoUniV3Pool.address, "10000000000");
          await token1
            .connect(user1)
            .approve(gelatoUniV3Pool.address, "10000000000");
          await gelatoUniV3Pool.connect(user1).mint(1000000);

          contractBalance0 = await token0.balanceOf(gelatoUniV3Pool.address);
          contractBalance1 = await token1.balanceOf(gelatoUniV3Pool.address);
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
          const slippagePrice2 = p2.add(p2.div(ethers.BigNumber.from("100")));
          await gelatoUniV3Pool
            .connect(gelato)
            .rebalance(
              -443580,
              443580,
              slippagePrice2,
              9000,
              100,
              token0.address
            );
          contractBalance0 = await token0.balanceOf(gelatoUniV3Pool.address);
          contractBalance1 = await token1.balanceOf(gelatoUniV3Pool.address);
          console.log(contractBalance0.toString(), contractBalance1.toString());

          await gelatoUniV3Pool
            .connect(user1)
            .burn(await gelatoUniV3Pool.balanceOf(await user1.getAddress()));

          contractBalance0 = await token0.balanceOf(gelatoUniV3Pool.address);
          contractBalance1 = await token1.balanceOf(gelatoUniV3Pool.address);
          console.log(contractBalance0.toString(), contractBalance1.toString());
          await gelatoUniV3Pool
            .connect(user0)
            .burn(await gelatoUniV3Pool.totalSupply());

          contractBalance0 = await token0.balanceOf(gelatoUniV3Pool.address);
          contractBalance1 = await token1.balanceOf(gelatoUniV3Pool.address);
          console.log(contractBalance0.toString(), contractBalance1.toString());

          expect(contractBalance0).to.equal(0);
          expect(contractBalance0).to.equal(0);
        });
      });
    });
  });
});
