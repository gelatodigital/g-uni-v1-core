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
  await weth.approve(gelatoUniV3Pool.address, ethers.utils.parseEther("10000"));
  await dai.approve(
    gelatoUniV3Pool.address,
    ethers.utils.parseEther("2000000")
  );
  await gelatoUniV3Pool.mint(ethers.utils.parseEther("1"), {
    gasLimit: 500000,
  });
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
