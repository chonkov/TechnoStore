const { ethers } = require("hardhat");

async function main() {
  const Token = await ethers.getContractFactory("Token");
  const token = await Token.deploy();

  console.log(`Token address: ${token.target}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
