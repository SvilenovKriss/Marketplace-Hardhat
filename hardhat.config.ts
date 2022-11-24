import { HardhatUserConfig, task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from 'dotenv'

import main from "./scripts/deploy-testnet";
import deployLocal from "./scripts/deploy-local";

dotenv.config();

task("deploy-local", "Deploys contract on local node")
  .setAction(async (params, hre: HardhatRuntimeEnvironment) => {
    await deployLocal(hre);
  });

task("deploy-testnet", "Deploys contract on a provided network")
  .setAction(async (params, hre: HardhatRuntimeEnvironment): Promise<void> => {
    await main(hre);
  });

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.GOERLI_PRIVATE_KEY || ''],
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  }
};

export default config;
