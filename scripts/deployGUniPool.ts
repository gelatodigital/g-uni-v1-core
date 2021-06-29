import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { getAddresses } from "../src/addresses";

const addresses = getAddresses(network.name);

const op = async (signer: SignerWithAddress) => {
  const gUniFactory = await ethers.getContractAt(
    "GUniFactory",
    addresses.GUniFactory,
    signer
  );

  await gUniFactory.createPool(
    addresses.WETH,
    addresses.DAI,
    3000,
    0,
    -200040,
    200040
  );
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
