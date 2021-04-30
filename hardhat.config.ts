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
      ...{
        UniswapV3Factory: "0xFeabCc62240297F1e4b238937D68e7516f0918D7",
        Gelato: "0xD90fC89e89E3E5b75256b5aA617f887C583b29a2",
        WETH: "0xc778417E063141139Fce010982780140Aa0cD5Ab",
        DAI: "0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa",
        MetaPoolFactory: "0xA78a6f698B7EF02E1783531De64D64D0992A55f1",
        gUNIV3: "0x586a331b4489F806EAE0A3d5AA80520692eF084C",
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
