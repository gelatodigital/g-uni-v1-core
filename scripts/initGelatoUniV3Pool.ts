import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { getAddresses } from "../src/addresses";

const addresses = getAddresses(network.name);

const op = async (signer: SignerWithAddress) => {
  const gelatoUniV3Pool = await ethers.getContractAt(
    "GelatoUniV3Pool",
    addresses.GUNIV3,
    signer
  );
  await gelatoUniV3Pool.initialize(
    ethers.utils.parseEther("20000"),
    -78900,
    -77100,
    false,
    await signer.getAddress(),
    { gasLimit: 1000000 }
  );
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
