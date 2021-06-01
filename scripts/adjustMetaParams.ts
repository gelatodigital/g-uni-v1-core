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
  await gelatoUniV3Pool.pool();
  /* METAPARAMS NOW HAVE INDIVIDUAL UPDATE METHODS
  await gelatoUniV3Pool.updateMetaParams(
    ethers.utils.parseEther("25"), // this is a param we are changing: lower supply cap
    "600",
    "120",
    "7000",
    "300",
    "5"
  );*/
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
