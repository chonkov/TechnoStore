require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || "";
const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x";

task("deploy", "Deploys 'TechnoStore' contract")
  .addPositionalParam("tokenAddr")
  .addPositionalParam("libraryAddr")
  .setAction(async (taskArgs, hre) => {
    const tokenAddr = taskArgs["tokenAddr"];
    const libraryAddr = taskArgs["libraryAddr"];

    const Token = await hre.ethers.getContractFactory("Token");
    const token = Token.attach(tokenAddr);

    const TechnoStore = await ethers.getContractFactory("TechnoStore", {
      libraries: {
        Library: libraryAddr,
      },
    });
    const technoStore = await TechnoStore.deploy(token.target);
    await technoStore.waitForDeployment();

    console.log(`Techno Store address: ${technoStore.target}`);
  });

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.19",
  networks: {
    hardhat: {
      chainId: 31337,
    },
    sepolia: {
      chainId: 11155111,
      url: SEPOLIA_RPC_URL,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
    },
  },
};
