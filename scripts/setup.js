const {ethers, network} = require('hardhat');
const bn = require('bignumber.js');

bn.config({ EXPONENTIAL_AT: 999999, DECIMAL_PLACES: 40 })

// returns the sqrt price as a 64x96
const encodePriceSqrt = (reserve1, reserve0) =>{
    return new bn(reserve1.toString())
      .div(reserve0.toString())
      .sqrt()
      .multipliedBy(new bn(2).pow(96))
      .integerValue(3)
      .toString()
}

const op = async (signer) => {
    const pool = await ethers.getContractAt("IUniswapV3Pool", network.config.addresses.V3PoolDaiWeth, signer);
    //await pool.initialize(encodePriceSqrt("1", "1000"), {gasLimit: 1000000});
    //console.log(await pool.slot0());
    //const dai = await ethers.getContractAt(["function allocateTo(address,uint256) external payable", "function approve(address,uint256) external"], network.config.addresses.Dai, signer);
    //await dai.allocateTo(await signer.getAddress(), ethers.utils.parseEther("100"));
    const s = await pool.slot0();
    console.log(s.sqrtPriceX96.toString());
}

(async() => {
    const [signer] = await ethers.getSigners();
    await op(signer);
})();