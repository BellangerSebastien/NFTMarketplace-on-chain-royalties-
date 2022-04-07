const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("TheShare", () => {
  describe("Marketplace", () => {
    let post;
    let signer;
    let market;

    const listingPrice = ethers.utils.parseEther('0.025');
    const auctionPrice = ethers.utils.parseEther('0.1');
    beforeEach(async () => {
      signer = await ethers.getSigner(0);
      const postFactory = await ethers.getContractFactory("PostNFT");
      post = await postFactory.deploy("MaximPost", "MPT", signer.address, 5);
      await post.deployed();
      const marketFactory = await ethers.getContractFactory("TheShareMarketplace");
      market = await marketFactory.deploy();
      await market.deployed();
    });

    it("Should be deployed successfully", async () => {
      expect(await post.name()).to.equal("MaximPost");
      expect(await post.symbol()).to.equal("MPT");
      expect(await market.listingPrice()).to.equal(ethers.utils.parseEther('0.025'));
      expect(await market.floorPrice()).to.equal(ethers.utils.parseEther('0.01'));

    });

    it("Should create market post item successfully", async () => {
      expect(await post.mint(signer.address, "Maxim's first post")).to.be;
      await post.setApprovalForAll(market.address, true);
      expect(await market.createMarketPostItem(post.address, 1, auctionPrice, { value: listingPrice })).to.be;
      const items = await market.fetchPostItemsCreated();
      expect(items.length).to.be.equal(1);
    });

    it("Should create market post item with EVENT", async function () {
      await post.mint(signer.address, "Maxim's first post");
      await post.setApprovalForAll(market.address, true);

      await expect(market.createMarketPostItem(post.address, 1, auctionPrice, { value: listingPrice }))
        .to.emit(market, 'MarketPostItemCreated')
        .withArgs(
          1,
          post.address,
          1,
          signer.address,
          ethers.constants.AddressZero,
          auctionPrice,
          0);
    });

    it("Should revert to create market post item if nft is not approved", async () => {
      await post.mint(signer.address, "Maxim's first post");
      await expect(market.createMarketPostItem(post.address, 1, auctionPrice, { value: listingPrice }))
        .to.be.revertedWith('Marketplace: Token is not approved.');
    });

    it("Should revert to purchase market post item if nft is transfered", async () => {
      const [account0, account1, account2] = await ethers.getSigners();
      await post.mint(signer.address, "Maxim's first post");
      await post.setApprovalForAll(market.address, true);
      expect(await market.createMarketPostItem(post.address, 1, auctionPrice, { value: listingPrice })).to.be;
      await post.transferFrom(signer.address, account1.address, 1);
      const txv = auctionPrice.add(listingPrice);
      await expect(market.connect(account2).purchasePost(1, { value: txv })).to.be.revertedWith("Token not approved nor owned");
    });

    it("Should create market post item and delete(de-list) successfully",async () => {
      const [account0, account1, account2] = await ethers.getSigners();
      await post.mint(signer.address, "Maxim's first post");
      await post.setApprovalForAll(market.address, true);
      await market.createMarketPostItem(post.address, 1, auctionPrice, { value: listingPrice });
      await market.deleteMarketPostItem(1);
      
      const txv = auctionPrice.add(listingPrice);
      await expect(market.connect(account1).purchasePost(1,{ value: txv })).to.be.revertedWith("Item is not active to be sold");
    });


  });

});
