import { HardhatUserConfig } from "hardhat/config";

// PLUGINS
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "solidity-coverage";
import "./lib/uniswap";

// TASKS
// import "./hardhat/tasks";

// Process Env Variables
import * as dotenv from "dotenv";
dotenv.config({ path: __dirname + "/.env" });
const ALCHEMY_ID = process.env.ALCHEMY_ID;
const DEPLOYER_PK_MAINNET = process.env.DEPLOYER_PK_MAINNET;
const DEPLOYER_PK = process.env.DEPLOYER_PK;

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",

  // hardhat-deploy
  namedAccounts: {
    deployer: {
      default: 0,
    },
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
    rinkeby: {
      accounts: DEPLOYER_PK ? [DEPLOYER_PK] : [],
      chainId: 4,
      url: `https://eth-rinkeby.alchemyapi.io/v2/${ALCHEMY_ID}`,
    },
    ropsten: {
      accounts: DEPLOYER_PK ? [DEPLOYER_PK] : [],
      chainId: 3,
      url: `https://eth-ropsten.alchemyapi.io/v2/${ALCHEMY_ID}`,
    },
  },

  solidity: "0.7.3",

  typechain: {
    outDir: "typechain",
    target: "ethers-v5",
  },
};

export default config;
