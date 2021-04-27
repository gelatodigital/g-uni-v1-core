const {ethers, network} = require('hardhat');

const op = async (signer) => {
    const metapool = await ethers.getContractAt("MetaPool", network.config.addresses.MetaPoolDaiWeth, signer);
    const pool = await metapool.currentPool();
    const swapper = await ethers.getContractAt("SwapTest", network.config.addresses.SwapTest);
    const dai = await ethers.getContractAt(["function approve(address,uint256) external"], network.config.addresses.Dai, signer);
    await dai.approve(network.config.addresses.SwapTest, ethers.utils.parseEther("1"));
    await swapper.swap(pool, true, ethers.utils.parseEther("1"), {gasLimit: 1000000});
}

(async() => {
    const [signer] = await ethers.getSigners();
    await op(signer);
})();