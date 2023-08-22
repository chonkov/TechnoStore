const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { getPermitSignature } = require("../utils/getPermitSignature");

const product = "Keyboard";
const quantity = 10;
const price = 50;
const amount = 50;
const deadline = 2000000000;

describe("TechnoStore", function () {
  async function deployERC20() {
    const [owner, ...other] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("Token");
    const token = await Token.deploy();

    await token.transfer(other[0].address, 1000);
    expect(await token.balanceOf(owner.address)).to.equal(9000);
    expect(await token.balanceOf(other[0].address)).to.equal(1000);

    return { token };
  }

  async function deployLibrary() {
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

  async function computePermitSignature() {
    const { token } = await loadFixture(deployERC20);
    const { technoStore } = await loadFixture(deployTechnoStore);
    const [owner] = await ethers.getSigners(1);

    const signature = await getPermitSignature(
      owner,
      token,
      technoStore.target,
      amount,
      deadline
    );

    const v = parseInt(signature.slice(130, 132), 16);
    const r = "0x" + signature.slice(2, 66);
    const s = "0x" + signature.slice(66, 130);

    return { v, r, s };
  }

  describe("Deployment", function () {
    it("Should set the right owner & token contract", async function () {
      const { token } = await loadFixture(deployERC20);
      const { technoStore } = await loadFixture(deployTechnoStore);
      const [owner] = await ethers.getSigners(1);

      expect(await technoStore.owner()).to.equal(owner.address);
      expect(await technoStore.token()).to.equal(token.target);
    });

    it("Should have an empty array of products intitially", async function () {
      const { technoStore } = await loadFixture(deployTechnoStore);

      expect(await technoStore.getAmountOfProducts()).to.equal(0);
    });
  });

  describe("Adding products", function () {
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

    it("Should revert, when the inputs are invalid", async function () {
      const { technoStore } = await loadFixture(deployTechnoStore);

      await expect(
        technoStore.addProduct(product, 0, price)
      ).to.be.revertedWith("Library__InvalidInputs");
      await expect(
        technoStore.addProduct(product, quantity, 0)
      ).to.be.revertedWith("Library__InvalidInputs");
    });

    it("Should revert, when the NOT the owner calls it", async function () {
      const { technoStore } = await loadFixture(deployTechnoStore);
      const [, ...other] = await ethers.getSigners();

      await expect(
        technoStore.connect(other[0]).addProduct("Laptop", 5, 100)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should emit an event", async function () {
      const { technoStore } = await loadFixture(deployTechnoStore);

      expect(await technoStore.addProduct(product, quantity, price))
        .to.emit(technoStore, "TechnoStore__ProductAdded")
        .withArgs(product, quantity);
    });
  });

  describe("Buying products", function () {
    it("Should revert, when the product, accessed with via index, does not exist", async function () {
      const { technoStore } = await loadFixture(deployTechnoStore);
      const { v, r, s } = await loadFixture(computePermitSignature);

      const [, ...other] = await ethers.getSigners();

      await expect(
        technoStore.connect(other[0]).buyProduct(0, amount, deadline, v, r, s)
      ).to.be.reverted;
    });

    it("Should revert, when there is insufficient amount of the desired product", async function () {
      const { technoStore } = await loadFixture(deployTechnoStore);
      const { v, r, s } = await loadFixture(computePermitSignature);

      const [, ...other] = await ethers.getSigners();

      await technoStore.addProduct(product, 1, price);
      await technoStore.buyProduct(0, amount, deadline, v, r, s);
      expect(await technoStore.getAmountOfProducts()).to.equal(1);
      expect(await technoStore.getQuantityOf(product)).to.equal(0);

      await expect(
        technoStore.connect(other[0]).buyProduct(0, amount, deadline, v, r, s)
      ).to.be.revertedWith("Library__InsufficientAmount");
    });

    it("Should not revert, when an address with enough tokens wants to buy a product", async function () {
      const { token } = await loadFixture(deployERC20);
      const { technoStore } = await loadFixture(deployTechnoStore);
      const { v, r, s } = await loadFixture(computePermitSignature);
      const [owner] = await ethers.getSigners(1);

      let tx = await technoStore.addProduct(product, quantity, price);
      await tx.wait();

      const initBalance = await token.balanceOf(owner.address);
      const initQuantity = await technoStore.getQuantityOf(product);

      tx = await technoStore.buyProduct(0, amount, deadline, v, r, s);
      await tx.wait();

      // Check all state changes that took place
      expect(await token.balanceOf(owner.address)).to.be.equal(
        initBalance - ethers.toBigInt(amount)
      );
      expect(await token.balanceOf(technoStore.target)).to.be.equal(amount);
      expect(await technoStore.getQuantityOf(product)).to.be.equal(
        initQuantity - ethers.toBigInt(1)
      );
      expect((await technoStore.getBuyersOf(product))[0]).to.be.equal(
        owner.address
      );
      expect(await technoStore.boughtAt(product, owner.address)).to.be.equal(
        tx.blockNumber
      );
    });

    it("Should revert, when a customer tries to buy a product more than once", async function () {
      const { technoStore } = await loadFixture(deployTechnoStore);
      const { v, r, s } = await loadFixture(computePermitSignature);

      await technoStore.addProduct(product, quantity, price);
      await technoStore.buyProduct(0, amount, deadline, v, r, s);

      await expect(
        technoStore.buyProduct(0, amount, deadline, v, r, s)
      ).to.be.revertedWith("Library__ProductAlreadyBought");
    });

    it("Should emit an event, when a product is bought", async function () {
      const { technoStore } = await loadFixture(deployTechnoStore);
      const { v, r, s } = await loadFixture(computePermitSignature);
      const [owner] = await ethers.getSigners(1);

      await technoStore.addProduct(product, quantity, price);

      expect(await technoStore.buyProduct(0, amount, deadline, v, r, s))
        .to.emit(technoStore, "TechnoStore__ProductBought")
        .withArgs(product, owner.address);
    });
  });

  describe("Refunding products", function () {
    it("Should revert, when customer has not bought the product", async function () {
      const { technoStore } = await loadFixture(deployTechnoStore);

      await technoStore.addProduct(product, quantity, price);
      await expect(technoStore.refundProduct(0)).to.be.revertedWith(
        "Library__ProductNotBought"
      );
    });

    it("Should revert, if the refund has expired", async function () {
      const { technoStore } = await loadFixture(deployTechnoStore);
      const { v, r, s } = await loadFixture(computePermitSignature);

      await technoStore.addProduct(product, quantity, price);
      await technoStore.buyProduct(0, amount, deadline, v, r, s);

      await network.provider.send("hardhat_mine", ["0x64"]);

      await expect(technoStore.refundProduct(0)).to.be.revertedWith(
        "Library__RefundExpired"
      );
    });

    it("Should successfully return 80% of the initial price to, when there is insufficient amount of the desired product", async function () {
      const { token } = await loadFixture(deployERC20);
      const { technoStore } = await loadFixture(deployTechnoStore);
      const { v, r, s } = await loadFixture(computePermitSignature);
      const [owner] = await ethers.getSigners(1);

      const initBalance = await token.balanceOf(owner.address);

      await technoStore.addProduct(product, quantity, price);
      await technoStore.buyProduct(0, amount, deadline, v, r, s);
      await expect(technoStore.refundProduct(0)).to.not.be.reverted;

      expect(await token.balanceOf(owner.address)).to.equal(
        initBalance - ethers.toBigInt(amount / 5)
      );
      expect(await token.balanceOf(technoStore.target)).to.equal(amount / 5);
      expect(await technoStore.getQuantityOf(product)).to.equal(quantity);
      expect(await technoStore.boughtAt(product, owner.address)).to.equal(0);
      expect((await technoStore.getBuyersOf(product))[0]).to.equal(
        owner.address
      );
      expect((await technoStore.getBuyersOf(product)).length).to.equal(1);
    });

    it("Should emit an event, if a refund is completed", async function () {
      const { technoStore } = await loadFixture(deployTechnoStore);
      const { v, r, s } = await loadFixture(computePermitSignature);
      const [owner] = await ethers.getSigners();

      await technoStore.addProduct(product, quantity, price);
      await technoStore.buyProduct(0, amount, deadline, v, r, s);
      expect(await technoStore.refundProduct(0))
        .to.emit(technoStore, "TechnoStore__ProductRefunded")
        .withArgs(product, owner.address);
    });
  });
});
