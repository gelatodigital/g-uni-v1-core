import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { getAddresses } from "../src/addresses";

const addresses = getAddresses(network.name);

const op = async (signer: SignerWithAddress) => {
  const gelatoUniV3Pool = await ethers.getContractAt(
    "GUniPoolStatic",
    addresses.GUNIWethUsdc,
    signer
  );
  await gelatoUniV3Pool.initialize(
    ethers.utils.parseEther("20000"),
    197100,
    199320,
    await signer.getAddress(),
    { gasLimit: 1000000 }
  );
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
