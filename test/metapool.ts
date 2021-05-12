import { expect } from "chai";
import { BigNumber } from "bignumber.js";
import { ethers, network } from "hardhat";
import {
  ERC20,
  IUniswapV3Factory,
  IUniswapV3Pool,
  MetaPoolFactory,
  SwapTest,
  MetaPool,
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

describe("MetaPools", function () {
  let uniswapFactory: IUniswapV3Factory;
  let uniswapPool: IUniswapV3Pool;
  let token0: ERC20;
  let token1: ERC20;
  let metaPoolFactory: MetaPoolFactory;
  const nonExistantToken = "0x1111111111111111111111111111111111111111";
  let user0: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let swapTest: SwapTest;
  let gelato: SignerWithAddress;

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

    const metaPoolFactoryFactory = await ethers.getContractFactory(
      "MetaPoolFactory"
    );
    metaPoolFactory = (await metaPoolFactoryFactory.deploy(
      uniswapFactory.address,
      await gelato.getAddress(),
      await user0.getAddress()
    )) as MetaPoolFactory;

    const mockERC20Factory = await ethers.getContractFactory("MockERC20");
    token0 = (await mockERC20Factory.deploy()) as ERC20;
    token1 = (await mockERC20Factory.deploy()) as ERC20;

    await token0.approve(
      swapTest.address,
      ethers.utils.parseEther("10000000000000")
    );
    await token1.approve(
      swapTest.address,
      ethers.utils.parseEther("10000000000000")
    );

    // Sort token0 & token1 so it follows the same order as Uniswap & the MetaPoolFactory
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
    const uniswapPoolAddress = await uniswapFactory.getPool(
      token0.address,
      token1.address,
      "3000"
    );
    uniswapPool = (await ethers.getContractAt(
      "IUniswapV3Pool",
      uniswapPoolAddress
    )) as IUniswapV3Pool;
    await uniswapPool.initialize(encodePriceSqrt("1", "1"));
  });

  describe("MetaPoolFactory", async function () {
    it("Should create a metapool for an existing Uniswap V3 pool", async function () {
      const tx = await metaPoolFactory.createPool(
        token0.address,
        token1.address,
        -887220,
        887220
      );
      const receipt = await tx.wait();
      let checkAddress = "";
      if (receipt.events && receipt.events.length == 3) {
        /*if (
          receipt.events[0].event &&
          receipt.events[0].args &&
          receipt.events[0].args.length >= 3
        ) {
          expect(receipt.events[0].event).to.equal("PoolCreated");
          expect(receipt.events[0].args[0]).to.equal(token0.address);
          expect(receipt.events[0].args[1]).to.equal(token1.address);
          checkAddress = receipt.events[0].args[2];
        } else if (
          receipt.events[1].event &&
          receipt.events[1].args &&
          receipt.events[1].args.length >= 3   
        ) {
          expect(receipt.events[1].event).to.equal("PoolCreated");
          expect(receipt.events[1].args[0]).to.equal(token0.address);
          expect(receipt.events[1].args[1]).to.equal(token1.address);
          checkAddress = receipt.events[1].args[2];         
        } else*/
        if (
          receipt.events[2].event &&
          receipt.events[2].args &&
          receipt.events[2].args.length >= 3
        ) {
          expect(receipt.events[2].event).to.equal("PoolCreated");
          expect(receipt.events[2].args[0]).to.equal(token0.address);
          expect(receipt.events[2].args[1]).to.equal(token1.address);
          checkAddress = receipt.events[2].args[2];
        }
      } else {
        expect(false).to.be.equal(true);
      }

      const calculatedAddress = await metaPoolFactory.calculatePoolAddress(
        token0.address,
        token1.address
      );

      expect(calculatedAddress).to.equal(checkAddress);

      const metaPool = (await ethers.getContractAt(
        "MetaPool",
        calculatedAddress
      )) as MetaPool;
      expect(await metaPool.currentPool()).to.equal(uniswapPool.address);
      expect(await metaPool.token0()).to.equal(token0.address);
      expect(await metaPool.token1()).to.equal(token1.address);
      expect(await metaPool.currentLowerTick()).to.equal(-887220);
      expect(await metaPool.currentUpperTick()).to.equal(887220);
      expect(await metaPool.currentUniswapFee()).to.equal(3000);
    });

    it("Should fail to create a metapool if there is no Uniswap 0.3% pool", async function () {
      await expect(
        metaPoolFactory.createPool(
          token0.address,
          nonExistantToken,
          -887220,
          887220
        )
      ).to.be.reverted;
    });

    it("Should fail to create the same pool twice", async function () {
      await metaPoolFactory.createPool(
        token0.address,
        token1.address,
        -887220,
        887220
      );
      await expect(
        metaPoolFactory.createPool(
          token0.address,
          token1.address,
          -887220,
          887220
        )
      ).to.be.reverted;
    });
  });

  describe("MetaPool", function () {
    let metaPool: MetaPool;

    beforeEach(async function () {
      await metaPoolFactory.createPool(
        token0.address,
        token1.address,
        -887220,
        887220
      );
      const calculatedAddress = await metaPoolFactory.calculatePoolAddress(
        token0.address,
        token1.address
      );
      metaPool = (await ethers.getContractAt(
        "MetaPool",
        calculatedAddress
      )) as MetaPool;

      await token0.approve(
        calculatedAddress,
        ethers.utils.parseEther("1000000")
      );
      await token1.approve(
        calculatedAddress,
        ethers.utils.parseEther("1000000")
      );
    });

    describe("deposits", function () {
      it("Should deposit funds into a metapool", async function () {
        await metaPool.mint("1000");

        expect(await token0.balanceOf(uniswapPool.address)).to.equal("1000");
        expect(await token1.balanceOf(uniswapPool.address)).to.equal("1000");
        const [liquidity] = await uniswapPool.positions(
          position(metaPool.address, -887220, 887220)
        );
        expect(liquidity).to.equal("1000");
        expect(await metaPool.totalSupply()).to.equal("1000");
        expect(await metaPool.balanceOf(await user0.getAddress())).to.equal(
          "1000"
        );

        await metaPool.mint("500");

        expect(await token0.balanceOf(uniswapPool.address)).to.equal("1500");
        expect(await token1.balanceOf(uniswapPool.address)).to.equal("1500");
        const [liquidity2] = await uniswapPool.positions(
          position(metaPool.address, -887220, 887220)
        );
        expect(liquidity2).to.equal("1500");
        expect(await metaPool.totalSupply()).to.equal("1500");
        expect(await metaPool.balanceOf(await user0.getAddress())).to.equal(
          "1500"
        );
      });
    });

    describe("rebalance", function () {
      it("should fail if not called by gelato", async function () {
        await expect(
          metaPool
            .connect(user1)
            .rebalance(
              -443610,
              443610,
              "3000",
              encodePriceSqrt("10", "1"),
              0,
              token0.address
            )
        ).to.be.reverted;
      });
      it("should fail if time did not change", async function () {
        await expect(
          metaPool
            .connect(gelato)
            .rebalance(
              -443610,
              443610,
              "3000",
              encodePriceSqrt("10", "1"),
              0,
              token0.address
            )
        ).to.be.reverted;
      });
    });

    describe("update accepted parameters", function () {
      it("should fail if not called by owner", async function () {
        await expect(
          metaPool
            .connect(gelato)
            .updateMetaParams(
              ethers.constants.MaxUint256,
              "42000",
              "60",
              "7000",
              false,
              "300",
              "3"
            )
        ).to.be.reverted;
      });
    });

    describe("with liquidity deposited", function () {
      beforeEach(async function () {
        await metaPool.mint("10000");
      });

      describe("withdrawal", function () {
        it("should burn LP tokens and withdraw funds", async function () {
          await metaPool.burn("6000");

          expect(await token0.balanceOf(uniswapPool.address)).to.equal("4001");
          expect(await token1.balanceOf(uniswapPool.address)).to.equal("4001");
          const [liquidity2] = await uniswapPool.positions(
            position(metaPool.address, -887220, 887220)
          );
          expect(liquidity2).to.equal("4000");
          expect(await metaPool.totalSupply()).to.equal("4000");
          expect(await metaPool.balanceOf(await user0.getAddress())).to.equal(
            "4000"
          );
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
              position(metaPool.address, -887220, 887220)
            );
            const gelatoBalanceBefore = await token0.balanceOf(
              await gelato.getAddress()
            );

            await expect(
              metaPool
                .connect(gelato)
                .rebalance(
                  -887220,
                  887220,
                  "3000",
                  encodePriceSqrt("1", "1"),
                  100,
                  token0.address
                )
            ).to.be.reverted;

            const tx = await metaPool
              .connect(user0)
              .updateMetaParams(
                ethers.constants.MaxUint256,
                "300",
                "60",
                "1000000",
                false,
                "300",
                "5"
              );
            await tx.wait();
            if (network.provider && user0.provider && tx.blockHash) {
              const block = await user0.provider.getBlock(tx.blockHash);
              const executionTime = block.timestamp + 300;
              await network.provider.send("evm_mine", [executionTime]);
            }

            await metaPool
              .connect(gelato)
              .rebalance(
                -887220,
                887220,
                "3000",
                encodePriceSqrt("1.1", "1"),
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
              position(metaPool.address, -887220, 887220)
            );
            expect(liquidityNew).to.be.gt(liquidityOld);
          });
        });

        describe("rebalance", function () {
          it("should change the ticks and rebalance", async function () {
            const [liquidityOld] = await uniswapPool.positions(
              position(metaPool.address, -887220, 887220)
            );
            const gelatoBalanceBefore = await token0.balanceOf(
              await gelato.getAddress()
            );

            await expect(
              metaPool
                .connect(gelato)
                .rebalance(
                  -443580,
                  443580,
                  "3000",
                  encodePriceSqrt("10000", "1"),
                  100,
                  token0.address
                )
            ).to.be.reverted;

            const tx = await metaPool
              .connect(user0)
              .updateMetaParams(
                ethers.constants.MaxUint256,
                "300",
                "60",
                "1000000",
                false,
                "300",
                "5"
              );
            await tx.wait();
            if (network.provider && tx.blockHash && user0.provider) {
              const block = await user0.provider.getBlock(tx.blockHash);
              const executionTime = block.timestamp + 300;
              await network.provider.send("evm_mine", [executionTime]);
            }

            await metaPool
              .connect(gelato)
              .rebalance(
                -443580,
                443580,
                "3000",
                encodePriceSqrt("1.1", "1"),
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
              position(metaPool.address, -887220, 887220)
            );
            expect(liquidityOldAfter).to.equal("0");
            expect(liquidityOldAfter).to.be.lt(liquidityOld);

            const [liquidityNew] = await uniswapPool.positions(
              position(metaPool.address, -443580, 443580)
            );
            expect(liquidityNew).to.be.gt(liquidityOld);
          });

          it("mint/burn without trading should result in same amounts", async function () {
            /*const [liquidityOld] = await uniswapPool.positions(
              position(metaPool.address, -887220, 887220)
            );*/
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
              .approve(metaPool.address, ethers.constants.MaxUint256);
            await token1
              .connect(user1)
              .approve(metaPool.address, ethers.constants.MaxUint256);
            await metaPool.connect(user1).mint(ethers.utils.parseEther("9"));
            await token0
              .connect(user2)
              .approve(metaPool.address, ethers.constants.MaxUint256);
            await token1
              .connect(user2)
              .approve(metaPool.address, ethers.constants.MaxUint256);
            await metaPool.connect(user2).mint(ethers.utils.parseEther("10"));

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

            await metaPool
              .connect(user2)
              .burn(await metaPool.balanceOf(await user2.getAddress()));
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

          it("should change the fee & ticks and rebalance", async function () {
            await uniswapFactory.createPool(
              token0.address,
              token1.address,
              500
            );
            const uniswapPoolAddress = await uniswapFactory.getPool(
              token0.address,
              token1.address,
              500
            );
            const pool2 = await ethers.getContractAt(
              "IUniswapV3Pool",
              uniswapPoolAddress
            );
            await pool2.initialize(encodePriceSqrt("1", "1"));
            const [liquidityOld] = await uniswapPool.positions(
              position(metaPool.address, -887220, 887220)
            );
            const gelatoBalanceBefore = await token0.balanceOf(
              await gelato.getAddress()
            );

            await expect(
              metaPool
                .connect(gelato)
                .rebalance(
                  -443580,
                  443580,
                  500,
                  encodePriceSqrt("1.1", "1"),
                  100,
                  token0.address
                )
            ).to.be.reverted;

            const tx = await metaPool
              .connect(user0)
              .updateMetaParams(
                ethers.constants.MaxUint256,
                "300",
                "60",
                "1000000",
                false,
                "300",
                "5"
              );
            await tx.wait();
            if (network.provider && tx.blockHash && user0.provider) {
              const block = await user0.provider.getBlock(tx.blockHash);
              const executionTime = block.timestamp + 300;
              await network.provider.send("evm_mine", [executionTime]);
            }

            await metaPool
              .connect(gelato)
              .rebalance(
                -443580,
                443580,
                500,
                encodePriceSqrt("1.1", "1"),
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
              position(metaPool.address, -887220, 887220)
            );
            expect(liquidityOldAfter).to.equal("0");
            expect(liquidityOldAfter).to.be.lt(liquidityOld);

            const [liquidityNew] = await pool2.positions(
              position(metaPool.address, -443580, 443580)
            );
            expect(liquidityNew).to.be.gt(liquidityOld);
          });
        });
      });

      describe("after lots of unbalanced trading", function () {
        beforeEach(async function () {
          await swapTest.washTrade(uniswapPool.address, "1000", 100, 4);
          await swapTest.washTrade(uniswapPool.address, "1000", 100, 4);
        });

        describe("reinvest fees", function () {
          it("should redeposit fees with a rebalance", async function () {
            const [liquidityOld] = await uniswapPool.positions(
              position(metaPool.address, -887220, 887220)
            );
            const gelatoBalanceBefore = await token0.balanceOf(
              await gelato.getAddress()
            );

            await expect(
              metaPool
                .connect(gelato)
                .rebalance(
                  -887220,
                  887220,
                  "3000",
                  encodePriceSqrt("1", "10"),
                  100,
                  token0.address
                )
            ).to.be.reverted;

            const tx = await metaPool
              .connect(user0)
              .updateMetaParams(
                ethers.constants.MaxUint256,
                "300",
                "60",
                "1000000",
                false,
                "300",
                "5"
              );
            await tx.wait();
            if (network.provider && user0.provider && tx.blockHash) {
              const block = await user0.provider.getBlock(tx.blockHash);
              const executionTime = block.timestamp + 300;
              await network.provider.send("evm_mine", [executionTime]);
            }

            const { sqrtPriceX96 } = await uniswapPool.slot0();
            const slippagePrice = sqrtPriceX96.sub(
              sqrtPriceX96
                .mul(ethers.BigNumber.from("4"))
                .div(ethers.BigNumber.from("100"))
            );

            await metaPool
              .connect(gelato)
              .rebalance(
                -887220,
                887220,
                "3000",
                slippagePrice,
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
              position(metaPool.address, -887220, 887220)
            );
            expect(liquidityNew).to.be.gt(liquidityOld);
          });
        });

        describe("rebalance", function () {
          it("should change the ticks and rebalance", async function () {
            const [liquidityOld] = await uniswapPool.positions(
              position(metaPool.address, -887220, 887220)
            );
            const gelatoBalanceBefore = await token0.balanceOf(
              await gelato.getAddress()
            );

            await expect(
              metaPool
                .connect(gelato)
                .rebalance(
                  -443580,
                  443580,
                  "3000",
                  encodePriceSqrt("1", "10000"),
                  100,
                  token0.address
                )
            ).to.be.reverted;

            const tx = await metaPool
              .connect(user0)
              .updateMetaParams(
                ethers.constants.MaxUint256,
                "300",
                "60",
                "1000000",
                false,
                "300",
                "5"
              );
            await tx.wait();
            if (network.provider && tx.blockHash && user0.provider) {
              const block = await user0.provider.getBlock(tx.blockHash);
              const executionTime = block.timestamp + 300;
              await network.provider.send("evm_mine", [executionTime]);
            }
            const { sqrtPriceX96 } = await uniswapPool.slot0();
            const slippagePrice = sqrtPriceX96.sub(
              sqrtPriceX96
                .mul(ethers.BigNumber.from("4"))
                .div(ethers.BigNumber.from("100"))
            );

            await metaPool
              .connect(gelato)
              .rebalance(
                -443580,
                443580,
                "3000",
                slippagePrice,
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
              position(metaPool.address, -887220, 887220)
            );
            expect(liquidityOldAfter).to.equal("0");
            expect(liquidityOldAfter).to.be.lt(liquidityOld);

            const [liquidityNew] = await uniswapPool.positions(
              position(metaPool.address, -443580, 443580)
            );
            expect(liquidityNew).to.be.gt(liquidityOld);
          });

          it("should change the fee & ticks and rebalance", async function () {
            await uniswapFactory.createPool(
              token0.address,
              token1.address,
              500
            );
            const uniswapPoolAddress = await uniswapFactory.getPool(
              token0.address,
              token1.address,
              500
            );
            const pool2 = await ethers.getContractAt(
              "IUniswapV3Pool",
              uniswapPoolAddress
            );
            await pool2.initialize(encodePriceSqrt("1", "1"));

            const [liquidityOld] = await uniswapPool.positions(
              position(metaPool.address, -887220, 887220)
            );
            const gelatoBalanceBefore = await token0.balanceOf(
              await gelato.getAddress()
            );

            await expect(
              metaPool
                .connect(gelato)
                .rebalance(
                  -443580,
                  443580,
                  500,
                  encodePriceSqrt("1", "10000"),
                  100,
                  token0.address
                )
            ).to.be.reverted;

            const tx = await metaPool
              .connect(user0)
              .updateMetaParams(
                ethers.constants.MaxUint256,
                "300",
                "60",
                "1000000",
                false,
                "300",
                "5"
              );
            await tx.wait();
            if (network.provider && tx.blockHash && user0.provider) {
              const block = await user0.provider.getBlock(tx.blockHash);
              const executionTime = block.timestamp + 300;
              await network.provider.send("evm_mine", [executionTime]);
            }
            const { sqrtPriceX96 } = await uniswapPool.slot0();
            const slippagePrice = sqrtPriceX96.sub(
              sqrtPriceX96
                .mul(ethers.BigNumber.from("4"))
                .div(ethers.BigNumber.from("100"))
            );

            await metaPool
              .connect(gelato)
              .rebalance(
                -443580,
                443580,
                500,
                slippagePrice,
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
              position(metaPool.address, -887220, 887220)
            );
            expect(liquidityOldAfter).to.equal("0");
            expect(liquidityOldAfter).to.be.lt(liquidityOld);

            const [liquidityNew] = await pool2.positions(
              position(metaPool.address, -443580, 443580)
            );
            expect(liquidityNew).to.be.gt(liquidityOld);
          });
        });
      });
    });
  });
});
