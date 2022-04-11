const { EtherscanProvider } = require("@ethersproject/providers");
const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("TheShare", () => {
  describe("Marketplace core functions", () => {
    let post;
    let book;
    let signer;
    let market;
    let listingFee;
    let listingFeeRecipient;

    const auctionPrice = ethers.utils.parseEther('0.1');
    beforeEach(async () => {
      signer = await ethers.getSigner(0);
      // To deploy PostNFT
      const postFactory = await ethers.getContractFactory("PostNFT");
      post = await postFactory.deploy("MaximPost", "MPT", "https://theshare.io/", signer.address, 5);
      // await post.deployed();
      // To deploy Book NFT
      const bookFactory = await ethers.getContractFactory("BookNFT");
      book = await bookFactory.deploy("MaximBook", "MBT", "https://theshare.io/", signer.address, 5);
      // To deploy marketplace
      const marketFactory = await ethers.getContractFactory("TheShareMarketplace");
      listingFeeRecipient = signer.address;
      market = await marketFactory.deploy(listingFeeRecipient, ethers.utils.parseEther('0.025'));
      // await market.deployed();
      listingFee = await market.listingFee();
    });

    it("Should be deployed successfully", async () => {
      // PostNFT
      expect(await post.name()).to.equal("MaximPost");
      expect(await post.symbol()).to.equal("MPT");
      //BookNFT
      expect(await book.name()).to.equal("MaximBook");
      expect(await book.symbol()).to.equal("MBT");
      expect(listingFee).to.equal(ethers.utils.parseEther('0.025'));

    });

    it("Should create market item successfully", async () => {
      //post item
      expect(await post.mint(signer.address, "Maxim's first post")).to.be;
      await post.setApprovalForAll(market.address, true);
      expect(await market.createMarketItem(true, post.address, 1, auctionPrice, 0, ethers.constants.AddressZero, { value: listingFee })).to.be;
      //book item
      const name = await book.name();
      const tokenId = 1;
      expect(await book.create(signer.address, tokenId, ethers.utils.parseEther('1000000'), `${name}/${tokenId}`, 0x0)).to.be;
      await book.setApprovalForAll(market.address, true);
      expect(await market.createMarketItem(false, book.address, tokenId, auctionPrice, ethers.utils.parseEther('1000'), ethers.constants.AddressZero, { value: listingFee })).to.be;
    });

    it("Should create market item with EVENT", async function () {
      //post item
      await post.mint(signer.address, "Maxim's first post");
      await post.setApprovalForAll(market.address, true);
      let itemId = ethers.utils.solidityKeccak256(['address', 'uint256', 'uint256', 'uint256', 'address'], [post.address, 1, auctionPrice, 0, ethers.constants.AddressZero]);
      await expect(market.createMarketItem(true, post.address, 1, auctionPrice, 0, ethers.constants.AddressZero, { value: listingFee }))
        .to.emit(market, 'MarketItemCreated')
        .withArgs(
          itemId,
          true,
          post.address,
          1,
          ethers.constants.AddressZero,
          0,
          auctionPrice
        );
      //book item
      const name = await book.name();
      const tokenId = 1;
      await book.create(signer.address, tokenId, ethers.utils.parseEther('1000000'), `${name}/${tokenId}`, 0x0);
      await book.setApprovalForAll(market.address, true);
      itemId = ethers.utils.solidityKeccak256(['address', 'uint256', 'uint256', 'uint256', 'address'], [book.address, tokenId, auctionPrice, ethers.utils.parseEther('1000'), ethers.constants.AddressZero]);
      expect(await market.createMarketItem(false, book.address, tokenId, auctionPrice, ethers.utils.parseEther('1000'), ethers.constants.AddressZero, { value: listingFee }))
        .to.emit(market, 'MarketItemCreated')
        .withArgs(
          itemId,
          false,
          book.address,
          tokenId,
          ethers.constants.AddressZero,
          ethers.utils.parseEther('1000'),
          auctionPrice
        );

    });

    it("Should revert to create market item if nft is not approved", async () => {
      // post item
      await post.mint(signer.address, "Maxim's first post");
      await expect(market.createMarketItem(true, post.address, 1, auctionPrice, 0, ethers.constants.AddressZero, { value: listingFee }))
        .to.be.revertedWith('Marketplace: Token is not approved.');
      //book item
      const name = await book.name();
      const tokenId = 1;
      await book.create(signer.address, tokenId, ethers.utils.parseEther('1000000'), `${name}/${tokenId}`, 0x0);
      await expect(market.createMarketItem(false, book.address, tokenId, auctionPrice, ethers.utils.parseEther('1000'), ethers.constants.AddressZero, { value: listingFee }))
        .to.be.revertedWith('Marketplace: Token is not approved.');
    });

    it("Should revert to purchase market post item if nft is transfered", async () => {
      //post item
      const [account0, account1, account2] = await ethers.getSigners();
      await post.mint(signer.address, "Maxim's first post");
      await post.setApprovalForAll(market.address, true);
      expect(await market.createMarketItem(true, post.address, 1, auctionPrice, 0, ethers.constants.AddressZero, { value: listingFee })).to.be;
      await post.transferFrom(signer.address, account1.address, 1);
      const itemId = ethers.utils.solidityKeccak256(['address', 'uint256', 'uint256', 'uint256', 'address'], [post.address, 1, auctionPrice, 0, ethers.constants.AddressZero]);

      await expect(market.connect(account2).purchaseItem(itemId, ethers.constants.AddressZero, { value: auctionPrice })).to.be.revertedWith("Token not approved nor owned");
    });

    it("Should create market post item and delete(de-list) successfully", async () => {
      const [account0, account1, account2] = await ethers.getSigners();
      await post.mint(signer.address, "Maxim's first post");
      await post.setApprovalForAll(market.address, true);
      await market.createMarketItem(true, post.address, 1, auctionPrice, 0, ethers.constants.AddressZero, { value: listingFee });
      const itemId = ethers.utils.solidityKeccak256(['address', 'uint256', 'uint256', 'uint256', 'address'], [post.address, 1, auctionPrice, 0, ethers.constants.AddressZero]);
      await market.cancelMarketItem(itemId);

      await expect(market.connect(account1).purchaseItem(itemId, ethers.constants.AddressZero, { value: auctionPrice })).to.be.reverted;
    });

    it("Should revert to delete with wrong params", async () => {
      const [account0, account1, account2] = await ethers.getSigners();
      await post.mint(signer.address, "Maxim's first post");
      await post.setApprovalForAll(market.address, true);
      await market.createMarketItem(true, post.address, 1, auctionPrice, 0, ethers.constants.AddressZero, { value: listingFee });
      const itemId = ethers.utils.solidityKeccak256(['address', 'uint256', 'uint256', 'uint256', 'address'], [post.address, 1, auctionPrice, 0, ethers.constants.AddressZero]);
      const wrongItemId = ethers.utils.solidityKeccak256(['address', 'uint256', 'uint256', 'uint256', 'address'], [post.address, 2, auctionPrice, 0, ethers.constants.AddressZero]);
      //not a correct post item id
      await expect(market.cancelMarketItem(wrongItemId)).to.be.revertedWith("Marketplace: Item is not listed at all");
      //not approved to market now
      // await post.setApprovalForAll(market.address, false);
      // await expect(market.cancelMarketItem(itemId)).to.be.revertedWith("Marketplace: Token is not approved.");
      //not owner
      // await post.setApprovalForAll(market.address, true);
      await expect(market.connect(account1).cancelMarketItem(itemId)).to.be.revertedWith("Marketplace: Market item can't be cancelled from other then seller or market owner. Aborting.");
      await post.transferFrom(account0.address, account1.address, 1);
      await expect(market.cancelMarketItem(itemId)).to.be.revertedWith("Marketplace: Not owner of the token");
    });


    it("Should seller, buyer and market owner correct MATIC value after sale", async () => {
      const [account0, account1, account2] = await ethers.getSigners();
      const marketOwnerBalance = await ethers.provider.getBalance(account0.address);
      await post.mint(account1.address, "Alice's first post");
      await post.connect(account1).setApprovalForAll(market.address, true);
      //create market item
      let sellerBal = await ethers.provider.getBalance(account1.address);
      let listingFeeRecipientBal = await ethers.provider.getBalance(listingFeeRecipient);
      let txresponse = await market.connect(account1).createMarketItem(true, post.address, 1, auctionPrice, 0, ethers.constants.AddressZero, { value: listingFee });
      const listingFeeRecipientBalAfterlisting = await ethers.provider.getBalance(listingFeeRecipient);
      const itemId = ethers.utils.solidityKeccak256(['address', 'uint256', 'uint256', 'uint256', 'address'], [post.address, 1, auctionPrice, 0, ethers.constants.AddressZero]);

      const sellerBalAfterSale = await ethers.provider.getBalance(account1.address);

      let txreceipt = await txresponse.wait();
      let gas = txreceipt.gasUsed.mul(txreceipt.effectiveGasPrice);

      //sellerBalAfterSale = sellerBal - listingFee - gas
      expect(sellerBalAfterSale).to.equal(sellerBal.sub(listingFee).sub(gas));
      //listing fee recipient balance
      expect(listingFeeRecipientBalAfterlisting).to.equal(listingFeeRecipientBal.add(listingFee));
      //purchase
      const buyerBalance = await ethers.provider.getBalance(account2.address);
      txresponse = await market.connect(account2).purchaseItem(itemId, ethers.constants.AddressZero, { value: auctionPrice });

      txreceipt = await txresponse.wait();
      const buyerBalAfterSale = await ethers.provider.getBalance(account2.address);
      console.log(buyerBalAfterSale);
      gas = txreceipt.gasUsed.mul(txreceipt.effectiveGasPrice);
      //buyerBalAfterSale = buyerBalance - auctionPrice - gas
      expect(buyerBalAfterSale).to.equal(buyerBalance.sub(auctionPrice).sub(gas));

    });

  });



});
