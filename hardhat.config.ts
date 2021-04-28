import { HardhatUserConfig } from "hardhat/config";

// PLUGINS
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
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
      ...{
        UniswapV3Factory: "0xFeabCc62240297F1e4b238937D68e7516f0918D7",
        Gelato: "0xD90fC89e89E3E5b75256b5aA617f887C583b29a2",
        T0: "0xe10700B6802dA40294551Da5cb1b45Ad7810fd1b",
        T1: "0xD926eB7496dDD17F5e3FB74B324f1c16D58398dd",
        MetaPoolFactory: "0x537f29A8ADa67e7d1950284eE82aF579B39BCb88",
        GULP: "0xfF0E61A880732c8CAA383ad28e54F80BF5704AaE",
        Swapper: "0x52327D6d94B77AEc83664A4e4758aEA5E34b8574",
      },
    },
  },

  solidity: "0.7.3",

  typechain: {
    outDir: "typechain",
    target: "ethers-v5",
  },
};

export default config;
