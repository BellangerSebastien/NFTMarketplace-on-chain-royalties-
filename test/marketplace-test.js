const { EtherscanProvider } = require("@ethersproject/providers");
const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("TheShare", () => {
  describe("Marketplace core functions", () => {
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
      await expect(market.connect(account2).purchasePost(1, { value: auctionPrice })).to.be.revertedWith("Token not approved nor owned");
    });

    it("Should create market post item and delete(de-list) successfully", async () => {
      const [account0, account1, account2] = await ethers.getSigners();
      await post.mint(signer.address, "Maxim's first post");
      await post.setApprovalForAll(market.address, true);
      await market.createMarketPostItem(post.address, 1, auctionPrice, { value: listingPrice });
      await market.deleteMarketPostItem(1);

      await expect(market.connect(account1).purchasePost(1, { value: auctionPrice })).to.be.revertedWith("Item is not active to be sold");
    });

    it("Should revert to delete with wrong params", async () => {
      const [account0, account1, account2] = await ethers.getSigners();
      await post.mint(signer.address, "Maxim's first post");
      await post.setApprovalForAll(market.address, true);
      await market.createMarketPostItem(post.address, 1, auctionPrice, { value: listingPrice });
      //not a correct post item id
      await expect(market.deleteMarketPostItem(2)).to.be.revertedWith("Marketplace: Invaild item ID");
      //not approved to market now
      await post.setApprovalForAll(market.address, false);
      await expect(market.deleteMarketPostItem(1)).to.be.revertedWith("Marketplace: Token is not approved.");
      //not owner
      await post.setApprovalForAll(market.address, true);
      await expect(market.connect(account1).deleteMarketPostItem(1)).to.be.revertedWith("Marketplace: Must be token owner");
      await post.transferFrom(account0.address, account1.address, 1);
      await expect(market.deleteMarketPostItem(1)).to.be.revertedWith("Marketplace: Must be token owner");
    });


    it("Should seller, buyer and market owner correct MATIC value after sale", async () => {
      const [account0, account1, account2] = await ethers.getSigners();
      const marketOwnerBalance = await ethers.provider.getBalance(account0.address);
      await post.mint(account1.address, "Alice's first post");
      await post.connect(account1).setApprovalForAll(market.address, true);
      //create market item
      let sellerBal = await ethers.provider.getBalance(account1.address);
      let txresponse = await market.connect(account1).createMarketPostItem(post.address, 1, auctionPrice, { value: listingPrice });
      const sellerBalAfterSale = await ethers.provider.getBalance(account1.address);

      let txreceipt = await txresponse.wait();
      let gas = txreceipt.gasUsed.mul(txreceipt.effectiveGasPrice);

      //sellerBalAfterSale = sellerBal - listingPrice - gas
      expect(sellerBalAfterSale).to.equal(sellerBal.sub(listingPrice).sub(gas));
      //purchase
      const buyerBalance = await ethers.provider.getBalance(account2.address);
      txresponse = await market.connect(account2).purchasePost(1, { value: auctionPrice });

      txreceipt = await txresponse.wait();
      const buyerBalAfterSale = await ethers.provider.getBalance(account2.address);
      gas = txreceipt.gasUsed.mul(txreceipt.effectiveGasPrice);
      //buyerBalAfterSale = buyerBalance - auctionPrice - gas
      expect(buyerBalAfterSale).to.equal(buyerBalance.sub(auctionPrice).sub(gas));

    });

  });

  describe("Marketplace fetch functions", () => {
    let post;
    let signer, account1, account2;
    let market;

    let listingPrice;
    const auctionPrice = ethers.utils.parseEther('0.1');
    beforeEach(async () => {
      [signer, account1, account2] = await ethers.getSigners();
      const postFactory = await ethers.getContractFactory("PostNFT");
      post = await postFactory.deploy("MaximPost", "MPT", signer.address, 5);
      await post.deployed();
      const marketFactory = await ethers.getContractFactory("TheShareMarketplace");
      market = await marketFactory.deploy();
      await market.deployed();
      listingPrice = await market.listingPrice();
      console.log(listingPrice);
      await post.setApprovalForAll(market.address, true);
      for (let i = 1; i <= 6; i++) {
        await post.mint(signer.address, "Max's posts");
        if (i <= 4)
          await market.createMarketPostItem(post.address, i, auctionPrice, { value: listingPrice });
      }

      for (let i = 7; i <= 9; i++) {
        await post.mint(account1.address, "Alice's posts");
      }

    });
    it("Should fetch active post items correctly", async () => {
      const postMarketItems = await market.fetchPostItemsCreated();
      expect(postMarketItems.length).to.equal(6);
    })
  });

});
