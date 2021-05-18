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
  const weth = await ethers.getContractAt(
    ["function approve(address,uint256) external"],
    addresses.WETH,
    signer
  );
  const dai = await ethers.getContractAt(
    ["function approve(address,uint256) external"],
    addresses.DAI,
    signer
  );

  // @dev change these amounts to your needs
  await weth.approve(metapool.address, ethers.utils.parseEther("1"));
  //await dai.approve(metapool.address, ethers.utils.parseEther("200"));
  await metapool.mint(ethers.utils.parseEther("5"), { gasLimit: 400000 });
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
