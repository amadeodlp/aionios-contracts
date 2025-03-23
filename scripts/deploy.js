const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying AIONIOS TimeCapsule contract...");

  // Get the Contract Factory
  const TimeCapsule = await ethers.getContractFactory("TimeCapsule");
  
  // Deploy the contract
  const timeCapsule = await TimeCapsule.deploy();
  
  // Wait for deployment to complete
  await timeCapsule.deployed();
  
  console.log("TimeCapsule deployed to:", timeCapsule.address);
  console.log("Transaction hash:", timeCapsule.deployTransaction.hash);
  
  // You should save this address in your .env file
  console.log("\nUpdate your .env file with:");
  console.log(`TIME_CAPSULE_ADDRESS=${timeCapsule.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
