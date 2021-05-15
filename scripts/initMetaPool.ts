import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { getAddresses } from "../src/addresses";

const addresses = getAddresses(network.name);

const op = async (signer: SignerWithAddress) => {
  const metaPoolFactory = await ethers.getContractAt(
    "MetaPoolFactory",
    addresses.MetaPoolFactory,
    signer
  );
  const tx = await metaPoolFactory.createPool(
    "Gelato Uniswap V3 WETH/DAI LP", //@dev token name
    addresses.WETH,
    addresses.DAI,
    -82500, // @dev can set your initial lower bound
    -81480, // @dev can set your initial upper bound
    { gasLimit: 4200000, gasPrice: ethers.BigNumber.from("100000000000") }
  );
  await tx.wait();
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
