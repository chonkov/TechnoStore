const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { getPermitSignature } = require("../utils/getPermitSignature");

describe("TechnoStore", function () {
  async function deployERC20() {
    const [owner, ...other] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("Token");
    const token = await Token.deploy();

    await token.transfer(other[0].address, 1000);
    expect(await token.balanceOf(owner.address)).to.equal(9000);
    expect(await token.balanceOf(other[0].address)).to.equal(1000);

    return { token, owner, other };
  }

  async function deployLibrary() {
    const [owner] = await ethers.getSigners();

    const Library = await ethers.getContractFactory("Library");
    const library = await Library.deploy();

    return { library };
  }

  async function deployTechnoStore() {
    const { token } = await loadFixture(deployERC20);
    const { library } = await loadFixture(deployLibrary);

    const TechnoStore = await ethers.getContractFactory("TechnoStore", {
      libraries: {
        Library: library.target,
      },
    });
    const technoStore = await TechnoStore.deploy(token.target);
    await technoStore.waitForDeployment();

    return { technoStore };
  }

  describe("Deployment", function () {
    it("Should set the right owner & token contract", async function () {
      const { token, owner } = await loadFixture(deployERC20);
      const { technoStore } = await loadFixture(deployTechnoStore);

      expect(await technoStore.owner()).to.equal(owner.address);
      expect(await technoStore.token()).to.equal(token.target);
    });

    it("Should have an empty array of products intitially", async function () {
      const { technoStore } = await loadFixture(deployTechnoStore);

      expect(await technoStore.getAmountOfProducts()).to.equal(0);
    });
  });

  describe("Adding products", function () {
    const product = "Keyboard";
    const quantity = 10;
    const price = 100;

    it("Should successfully add a product to the store with its corresponding price and quantity", async function () {
      const { technoStore } = await loadFixture(deployTechnoStore);

      const tx = await technoStore.addProduct(product, quantity, price);
      await tx.wait();

      expect(await technoStore.getAmountOfProducts()).to.equal(1);
      expect(await technoStore.products(0)).to.equal(product);
      expect(await technoStore.getQuantityOf(product)).to.equal(quantity);
      expect(await technoStore.getPriceOf(product)).to.equal(price);
    });

    it("Should just increase the quantity, if the same product is added twice", async function () {
      const { technoStore } = await loadFixture(deployTechnoStore);

      let tx = await technoStore.addProduct(product, quantity, price);
      await tx.wait();

      tx = await technoStore.addProduct(product, quantity, price);
      await tx.wait();

      expect(await technoStore.getAmountOfProducts()).to.equal(1);
      expect(await technoStore.getQuantityOf(product)).to.equal(quantity * 2);
    });

    it("Should emit an event", async function () {
      const { technoStore } = await loadFixture(deployTechnoStore);

      expect(await technoStore.addProduct(product, quantity, price))
        .to.emit(technoStore, "TechnoStore__ProductAdded")
        .withArgs(product, quantity);
    });
  });

  describe("Buying products", function () {
    const product = "Keyboard";
    const quantity = 10;
    const price = 50;
    const signature =
      "0x566a940ae90d8778cb45db507ecd1bf2ee9c312c5b550de9fecfbe006906361475bb13d49ef3bf2cde32089c6ea1a0ce3cdcae02d5a144ca527817661f20f65b1b"; // demo signature - not valid

    it.skip("Should revert, when the product, accessed with via index, does not exist", async function () {
      const { technoStore } = await loadFixture(deployTechnoStore);
      const [, ...other] = await ethers.getSigners();

      await expect(technoStore.connect(other[0]).buyProduct(0, signature)).to.be
        .reverted;
    });

    it.skip("Should revert, when there is insufficient amount of the desired product", async function () {
      const { technoStore } = await loadFixture(deployTechnoStore);
      const [, ...other] = await ethers.getSigners();

      await technoStore.addProduct(product, 0, price);
      expect(await technoStore.getAmountOfProducts()).to.equal(1);
      expect(await technoStore.getQuantityOf(product)).to.equal(0);

      await expect(
        technoStore.connect(other[0]).buyProduct(0, signature)
      ).to.be.revertedWith("Library__InsufficientAmount");
    });

    it.only("Should not revert, when an address with enough tokens wants to buy a product", async function () {
      const { token, owner } = await loadFixture(deployERC20);
      const { technoStore } = await loadFixture(deployTechnoStore);

      const tx = await technoStore.addProduct(product, quantity, price);
      await tx.wait();

      const value = 100;
      const deadline = 2000000000;
      const signature = await getPermitSignature(
        owner,
        token,
        technoStore.target,
        value,
        deadline
      );

      console.log(signature);
      const v = parseInt(signature.slice(130, 132), 16);
      const r = "0x" + signature.slice(2, 66);
      const s = "0x" + signature.slice(66, 130);
      console.log("_______________________________________________________");
      console.log(`r: ${r}`);
      console.log(`s: ${s}`);
      console.log(`v: ${v}`);

      const result = await token.test(
        owner.address,
        technoStore.target,
        value,
        deadline,
        v,
        r,
        s
      );
      console.log("_______________________________________________________");
      console.log("HERE OWNER", owner.address);
      console.log(result);
    });
  });
});
