import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { getAddresses } from "../hardhat/addresses";

const addresses = getAddresses(network.name);

const op = async (signer: SignerWithAddress) => {
  if (network.name == "rinkeby") {
    const dai = await ethers.getContractAt(
      ["function allocateTo(address,uint256) external"],
      addresses.DAI,
      signer
    );
    await dai.allocateTo(
      await signer.getAddress(),
      ethers.utils.parseEther("100"),
      { gasLimit: 6000000 }
    );
  } else if (network.name == "ropsten") {
    const dai = await ethers.getContractAt(
      ["function mint(uint256) external"],
      addresses.DAI,
      signer
    );
    await dai.mint(ethers.utils.parseEther("1000"), { gasLimit: 6000000 });
  }
};

(async () => {
  const [signer] = await ethers.getSigners();
  await op(signer);
})();
