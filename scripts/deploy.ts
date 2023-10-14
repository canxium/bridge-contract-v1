import { ethers } from "hardhat";

async function main() {

  const lock = await ethers.deployContract(
    "SideChainBridge",
    ["0x4C8414F37793A01E5E391642E75f9Ed8e7B63C49", "0xe4084F223BE4FF34eD452e24a86bF10ffe3fb0B7"],
    {
      maxFeePerGas: 280000000000,
      maxPriorityFeePerGas: 1000000000
    }
  );

  await lock.waitForDeployment();
  console.log(
    `Deployed to ${lock.target}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
