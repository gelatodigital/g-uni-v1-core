import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { getAddresses } from "../src/addresses";

const addresses = getAddresses(network.name);

const op = async (signer: SignerWithAddress) => {
  const gelatoUniV3Router = await ethers.getContractAt(
    "GelatoUniV3Router",
    addresses.GUNIRouter,
    signer
  );
  /*const weth = await ethers.getContractAt(
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
  await weth.approve(gelatoUniV3Pool.address, ethers.utils.parseEther("10000"));
  await dai.approve(
    gelatoUniV3Pool.address,
    ethers.utils.parseEther("2000000")
  );*/
  await gelatoUniV3Router.mintFromMaxAmounts(
    addresses.GUNIV3,
    ethers.utils.parseEther("500"),
    ethers.constants.Zero,
    {
      gasLimit: 500000,
    }
  );
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
