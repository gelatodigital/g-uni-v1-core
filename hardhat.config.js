require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require("hardhat-deploy");
require("hardhat-deploy-ethers");
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-etherscan");
require("./lib/uniswap");
const assert = require('assert');

// Process Env Variables
require("dotenv").config();

const ALCHEMY_ID = process.env.ALCHEMY_ID;
assert.ok(ALCHEMY_ID, "no Alchemy ID in process.env");

const DEPLOYER_PK_MAINNET = process.env.DEPLOYER_PK_MAINNET;
const DEPLOYER_PK = process.env.DEPLOYER_PK;

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },

  gasReporter: {
    enabled: process.env.REPORT_GAS ? true : false,
    maxMethodDiff: 25,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  },

  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },

  networks: {
    mainnet: {
      accounts: DEPLOYER_PK_MAINNET ? [DEPLOYER_PK_MAINNET] : [],
      chainId: 1,
      url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_ID}`,
    },
    ropsten: {
      accounts: DEPLOYER_PK ? [DEPLOYER_PK] : [],
      chainId: 3,
      url: `https://eth-ropsten.alchemyapi.io/v2/${ALCHEMY_ID}`,
    },
    rinkeby: {
      accounts: DEPLOYER_PK ? [DEPLOYER_PK] : [],
      chainId: 4,
      url: `https://eth-rinkeby.alchemyapi.io/v2/${ALCHEMY_ID}`,
      addresses: {
        UniswapV3Factory: "0xFeabCc62240297F1e4b238937D68e7516f0918D7",
        Gelato: "0x4B5BaD436CcA8df3bD39A095b84991fAc9A226F1",
        V3PoolDaiWeth: "0x4E3f5778bafE258e4E75786f38fa3f8bE34Ad7f2",
        Dai: "0x5592ec0cfb4dbc12d3ab100b257153436a1f0fea",
        Weth: "0xc778417E063141139Fce010982780140Aa0cD5Ab",
        MetaPoolFactory: "0x7b76b4FACd224072E8bA14375963d06434831196",
        MetaPoolDaiWeth: "0xe3026254bF8d657cfbA9F640C5EF8c3Bf3153B5e",
        SwapTest: "0x793846acA2c0775dC8abE6C93b8d55d82146Dc21",
      }
    },
  },
  solidity: "0.7.3",
};

