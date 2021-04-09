import { Contract, ContractFactory } from "ethers";
// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";
import NetworkAddresses from "../networkAddresses.json";

export async function deployThem(): Promise<Contract> {
  // Hardhat always runs the compile task when running scripts through it.
  // If this runs in a standalone fashion you may want to call compile manually
  // to make sure everything is compiled
  // await run("compile");
  const DeploymentNetwork = "kovan";
  const networkAddresses = NetworkAddresses[DeploymentNetwork];

  // DSProxyFactory
  const DSProxyFactory: ContractFactory = await ethers.getContractFactory("DSProxyFactory");
  const dSProxyFactory: Contract = await DSProxyFactory.deploy();
  await dSProxyFactory.deployed();
  console.log("DSProxyFactory deployed to: ", dSProxyFactory.address);

  // DSGuardFactory
  const DSGuardFactory: ContractFactory = await ethers.getContractFactory("DSGuardFactory");
  const dSGuardFactory: Contract = await DSGuardFactory.deploy();
  await dSGuardFactory.deployed();
  console.log("DSGuardFactory deployed to: ", dSGuardFactory.address);

  // Liquity BorrowerOperations
  const ProxyBorrowerOperations: ContractFactory = await ethers.getContractFactory("BorrowerOperationsScript");
  const proxyBorrowerOperations: Contract = await ProxyBorrowerOperations.deploy(
    networkAddresses.LiquityBorrowerOperations,
    networkAddresses.LUSD,
  );
  await proxyBorrowerOperations.deployed();
  console.log("ProxyBorrowerOperations deployed to: ", proxyBorrowerOperations.address);

  // Vault Migration
  const VaultMigration: ContractFactory = await ethers.getContractFactory("VaultMigration");
  const vaultMigration: Contract = await VaultMigration.deploy(
    networkAddresses.UniswapFactory,
    networkAddresses.UniswapRouter,
    networkAddresses.MakerProxyActions,
    proxyBorrowerOperations.address,
    networkAddresses.ETH_A_GemJoin,
    networkAddresses.ETH_B_GemJoin,
    dSGuardFactory.address,
    networkAddresses.DAI,
    networkAddresses.WETH,
    networkAddresses.LUSD,
  );
  await vaultMigration.deployed();
  console.log("VaultMigration deployed to: ", vaultMigration.address);

  return vaultMigration;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
deployThem()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
