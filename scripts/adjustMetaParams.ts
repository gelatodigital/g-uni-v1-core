import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { getAddresses } from "../src/addresses";

const addresses = getAddresses(network.name);

const op = async (signer: SignerWithAddress) => {
  const metapool = await ethers.getContractAt(
    "MetaPool",
    addresses.gUNIV3,
    signer
  );
  await metapool.updateMetaParams(
    ethers.utils.parseEther("25"),
    "600",
    "120",
    "7000",
    true,
    "300",
    "5"
  );
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
