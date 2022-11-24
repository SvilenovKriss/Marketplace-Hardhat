import { HardhatRuntimeEnvironment } from "hardhat/types";

async function deployLocal(hre: HardhatRuntimeEnvironment) {
    await hre.run('compile');

    const [deployer] = await hre.ethers.getSigners();

    console.log('Deploying contracts with the account:', deployer.address);
    console.log('Account balance:', (await deployer.getBalance()).toString());

    const Marketplace = await hre.ethers.getContractFactory("Marketplace");
    const marketplaceContract = await Marketplace.deploy();
    console.log('Waiting for BookLibrary deployment...');

    await marketplaceContract.deployed();

    console.log('Marketplace Contract address: ', marketplaceContract.address);
    console.log('Done!');
}

export default deployLocal;