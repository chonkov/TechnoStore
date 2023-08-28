const { ethers } = require("hardhat");

async function main() {
  const Library = await ethers.getContractFactory("Library");
  const library = await Library.deploy();

  console.log(`Library address: ${library.target}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
