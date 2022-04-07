const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("TheShare", () => {
  describe("Marketplace", () => {
    let post;
    let signer;
    let market;
    const listingPrice = ethers.utils.parseEther('0.025');

    beforeEach(async () => {
      signer = await ethers.getSigner(0);
      const postFactory = await ethers.getContractFactory("PostNFT");
      post = await postFactory.deploy("MaximPost", "MPT", signer.address, 5);
      await post.deployed();
      const marketFactory = await ethers.getContractFactory("TheShareMarketplace");
      market = await marketFactory.deploy();
      await market.deployed();
    });

    it("Deployed successfully",async ()=>{
      expect(await post.name()).to.equal("MaximPost");
      expect(await post.symbol()).to.equal("MPT");
      expect(await market.listingPrice()).to.equal(ethers.utils.parseEther('0.025'));
      expect(await market.floorPrice()).to.equal(ethers.utils.parseEther('0.025'));

    });

    it("Create market post item", async () => {
      expect(await post.mint(signer.address, "Maxim's first post")).to.be;
      await post.setApprovalForAll(market.address,true);
      expect(await market.createMarketPostItem(post.address, 1, ethers.utils.parseEther('0.1'), { value: listingPrice })).to.be;

    });
  });

});
