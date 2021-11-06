import { expect } from "chai";
import { ethers, network } from "hardhat";
import {
  IUniswapV3Pool,
  GUniPool,
  GUniFactory,
} from "../typechain";
import {getAddresses} from "../src/addresses";
//import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
const addresses = getAddresses("mainnet");
const manager = "0x5A16552f59ea34E44ec81E58b3817833E9fD5436"

describe("GUniPool", function () {
  this.timeout(0);

  let factory: GUniFactory;
  let pool: GUniPool;
  let uniswapPool: IUniswapV3Pool;
  let manager: string;

  before(async function () {
    factory = (await ethers.getContractAt(
      "GUniFactory",
      addresses.GUniFactory
    )) as GUniFactory;
    const pools = await factory.getPools(manager);
    expect(pools.length).to.equal(1);

    pool = (await ethers.getContractAt("GUniPool", pools[0])) as GUniPool;
  });

  it("executive rebalances", async function () {
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [manager],
    });
    const managerSigner = await ethers.provider.getSigner(manager);
    const {amount0Current, amount1Current} = await pool.getUnderlyingBalances();
  });
});
