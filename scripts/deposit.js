const {ethers, network} = require('hardhat');

const op = async (signer) => {
    const metapool = await ethers.getContractAt("MetaPool", network.config.addresses.MetaPoolDaiWeth, signer);
    const dai = await ethers.getContractAt(["function approve(address,uint256) external"], network.config.addresses.Dai, signer);
    const weth = await ethers.getContractAt(["function approve(address,uint256) external"], network.config.addresses.Weth, signer);
    await dai.approve(metapool.address, ethers.utils.parseEther("1"));
    await weth.approve(metapool.address, ethers.utils.parseEther("1"));
    await metapool.mint(ethers.utils.parseEther("1"), {gasLimit: 1000000});
}

(async() => {
    const [signer] = await ethers.getSigners();
    await op(signer);
})();