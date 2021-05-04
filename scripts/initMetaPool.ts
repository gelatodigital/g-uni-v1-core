import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { getAddresses } from "../hardhat/addresses";

const addresses = getAddresses(network.name);

const op = async (signer: SignerWithAddress) => {
  const metaPoolFactory = await ethers.getContractAt(
    "MetaPoolFactory",
    addresses.MetaPoolFactory,
    signer
  );
  const tx = await metaPoolFactory.createPool(
    addresses.WETH,
    addresses.DAI,
    -47040, // @dev can set your initial lower bound
    -45000, // @dev can set your initial upper bound
    { gasLimit: 6000000 }
  );
  await tx.wait();
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
