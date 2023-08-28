const { ethers } = require("hardhat");

async function main() {
  const Token = await ethers.getContractFactory("Token");
  const token = await Token.deploy();

  console.log(`Token address: ${token.target}`);

  const Library = await ethers.getContractFactory("Library");
  const library = await Library.deploy();
  console.log(`Library address: ${library.target}`);

  const TechnoStore = await ethers.getContractFactory("TechnoStore", {
    libraries: {
      Library: library.target,
    },
  });
  const technoStore = await TechnoStore.deploy(token.target);
  await technoStore.waitForDeployment();
  console.log(`Techno Store address: ${technoStore.target}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
