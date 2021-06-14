import hre from "hardhat";
import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { getAddresses } from "../src/addresses";

const addresses = getAddresses(network.name);

const op = async (signer: SignerWithAddress) => {
  const abi = (await hre.artifacts.readArtifact("IUniswapV3Pool"))["abi"];
  const pool = new ethers.Contract(addresses.WethInstV3Pool, abi, signer);
  await pool.increaseObservationCardinalityNext("40", {
    gasLimit: 1000000,
  });
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
