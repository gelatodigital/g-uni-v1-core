import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { getAddresses } from "../src/addresses";

const addresses = getAddresses(network.name);

const op = async (signer: SignerWithAddress) => {
  const gelatoUniV3Pool = await ethers.getContractAt(
    "GUniPoolStatic",
    addresses.GUNIWethDai,
    signer
  );
  await gelatoUniV3Pool.burn(ethers.utils.parseEther("5"), {
    gasLimit: 6000000,
  });
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
