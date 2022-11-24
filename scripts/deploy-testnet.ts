import { HardhatRuntimeEnvironment } from "hardhat/types";
import * as dotenv from 'dotenv'

dotenv.config();

interface ErrorMessage {
  message: string;
}

async function main(hre: HardhatRuntimeEnvironment): Promise<void> {
  await hre.run('compile');

  const wallet = new hre.ethers.Wallet(process.env.PRIVATE_KEY || '', hre.ethers.provider)
  console.log('Account balance:', (await wallet.getBalance()).toString());

  const MarketplaceFactory = await hre.ethers.getContractFactory("Marketplace");
  const marketplaceContract = await MarketplaceFactory.deploy();

  console.log('Waiting for contract to deploy...');

  await marketplaceContract.deployed();

  await new Promise(() => {
    setTimeout(async () => {
      console.log('Waiting contract to be verified on etherscan');
      try {
        console.log("Verifying contract...");
        await hre.run("verify:verify", {
          address: marketplaceContract.address,
        });
      } catch (err: (ErrorMessage | any)) {
        if (err.message.includes("Reason: Already Verified")) {
          await hre.run('print', { address: marketplaceContract.address });
        }
      }
    }, 60000);
  });
}

export default main;
