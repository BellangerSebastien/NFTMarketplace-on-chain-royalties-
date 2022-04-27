const { EtherscanProvider } = require("@ethersproject/providers");
const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("TheShare", () => {
  describe("Marketplace core functions", () => {
    let post;
    let book;
    let signer;
    let market;
    let marketFee;
    let marketFeeRecipient;
    let floorPrice;

    const auctionPrice = ethers.utils.parseEther('0.1');
    beforeEach(async () => {
      signer = await ethers.getSigner(0);
      // To deploy PostNFT
      const postFactory = await ethers.getContractFactory("PostNFT");
      post = await postFactory.deploy("TheSharePost", "TSPT", "https://theshare.io/", signer.address, 500);
      // await post.deployed();
      // To deploy Book NFT
      const bookFactory = await ethers.getContractFactory("BookNFT");
      book = await bookFactory.deploy("TheShareBook", "TSBT", "https://theshare.io/", signer.address, 500);
      // To deploy TheShareToken
      const tokenFactory = await ethers.getContractFactory("TheShareToken");
      erc20token = await tokenFactory.deploy();
      // To deploy marketplace
      const marketFactory = await ethers.getContractFactory("TheShareMarketplace");
      marketFeeRecipient = signer.address;
      market = await marketFactory.deploy(marketFeeRecipient, 200, ethers.utils.parseEther('0.01'));
      // await market.deployed();
      marketFee = await market.getMarketFee();
      floorPrice = await market.floorPrice();
    });

    it("Should be deployed successfully", async () => {
      // PostNFT
      expect(await post.name()).to.equal("TheSharePost");
      expect(await post.symbol()).to.equal("TSPT");
      // BookNFT
      expect(await book.name()).to.equal("TheShareBook");
      expect(await book.symbol()).to.equal("TSBT");
      // TheShareToken
      expect(await erc20token.name()).to.equal("TheShareToken");
      expect(await erc20token.symbol()).to.equal("TST");
      expect(await erc20token.totalSupply()).to.equal(ethers.utils.parseEther("100000000000"));

      expect(marketFee).to.equal(200);
      expect(floorPrice).to.equal(ethers.utils.parseEther('0.01'));

    });

    it("Should create market item successfully", async () => {
      // post item
      expect(await post.mint(signer.address, "Maxim's first post")).to.be;
      await post.approve(market.address, 1);
      expect(await market.createMarketItem(true, post.address, 1, auctionPrice, 1, ethers.constants.AddressZero)).to.be;
      // book item
      const name = await book.name();
      const tokenId = 1;
      expect(await book.create(signer.address, tokenId, 1000000, "", 0x0)).to.be;
      await book.setApprovalForAll(market.address, true);
      expect(await market.createMarketItem(false, book.address, tokenId, auctionPrice, 1000, ethers.constants.AddressZero)).to.be;
    });

    it("Should create market item with EVENT", async function () {
      //post item
      await post.mint(signer.address, "Maxim's first post");
      await post.approve(market.address, 1);
      let itemId = ethers.utils.solidityKeccak256(['address', 'uint256', 'uint256', 'address'], [post.address, 1, 1, signer.address]);
      await expect(market.createMarketItem(true, post.address, 1, auctionPrice, 1, ethers.constants.AddressZero))
        .to.emit(market, 'MarketItemUpdated')
        .withArgs(
          itemId,
          true,
          post.address,
          1,
          ethers.constants.AddressZero,
          1,
          auctionPrice
        );
      //book item
      const name = await book.name();
      const tokenId = 1;
      await book.create(signer.address, tokenId, 1000000, "", 0x0);
      await book.setApprovalForAll(market.address, true);
      itemId = ethers.utils.solidityKeccak256(['address', 'uint256', 'uint256', 'address'], [book.address, 1, 1000, signer.address]);
      expect(await market.createMarketItem(false, book.address, tokenId, auctionPrice, 1000, ethers.constants.AddressZero))
        .to.emit(market, 'MarketItemUpdated')
        .withArgs(
          itemId,
          false,
          book.address,
          tokenId,
          ethers.constants.AddressZero,
          1000,
          auctionPrice
        );

    });

    it("Should revert to create market item if nft is not approved", async () => {
      // post item
      await post.mint(signer.address, "Maxim's first post");
      await expect(market.createMarketItem(true, post.address, 1, auctionPrice, 1, ethers.constants.AddressZero))
        .to.be.revertedWith('Marketplace: Token is not approved.');
      //book item
      const name = await book.name();
      const tokenId = 1;
      await book.create(signer.address, tokenId, 1000000, "", 0x0);
      await expect(market.createMarketItem(false, book.address, tokenId, auctionPrice, 1000, ethers.constants.AddressZero))
        .to.be.revertedWith('Marketplace: Token is not approved.');
    });

    it("Should revert to purchase market post item if nft is transfered", async () => {
      // post item
      const [account0, account1, account2] = await ethers.getSigners();
      await post.mint(signer.address, "Maxim's first post");
      await post.approve(market.address, 1);
      // payment method: ETH
      // expect(await market.createMarketItem(true, post.address, 1, auctionPrice, 1, ethers.constants.AddressZero)).to.be;
      // payment method: erc20
      expect(await market.createMarketItem(true, post.address, 1, auctionPrice, 1, erc20token.address)).to.be;
      await post.transferFrom(signer.address, account1.address, 1);
      let itemId = ethers.utils.solidityKeccak256(['address', 'uint256', 'uint256', 'address'], [post.address, 1, 1, signer.address]);
      let priceWithFee = auctionPrice.mul(marketFee.add(10000)).div(10000);
      // await expect(market.connect(account2).purchaseItem(itemId, 1, ethers.constants.AddressZero, { value: priceWithFee })).to.be.revertedWith("Token not approved nor owned");
      await expect(market.connect(account2).purchaseItem(itemId, 1, erc20token.address, { value: priceWithFee })).to.be.revertedWith("Token not approved nor owned");

      // book item
      const name = await book.name();
      const tokenId = 1;
      await book.create(signer.address, tokenId, 1000000, "", 0x0);
      await book.setApprovalForAll(market.address, true);
      await market.createMarketItem(false, book.address, tokenId, auctionPrice, 1000, ethers.constants.AddressZero);
      await book.safeTransferFrom(signer.address, account1.address, tokenId, 1000000, 0x0);
      itemId = ethers.utils.solidityKeccak256(['address', 'uint256', 'uint256', 'address'], [book.address, tokenId, 1000, signer.address]);
      // await expect(market.connect(account2).purchaseItem(itemId, 1000, ethers.constants.AddressZero, { value: priceWithFee.mul(1000) }))
      await expect(market.connect(account2).purchaseItem(itemId, 1000, erc20token.address, { value: priceWithFee.mul(1000) }))
        .to.be.revertedWith("Marketplace: ERC1155 insufficient balance of the token.");
    });

    it("Should create market post item and delete(de-list) successfully", async () => {
      const [account0, account1, account2] = await ethers.getSigners();

      // post item
      await post.mint(signer.address, "Maxim's first post");
      await post.approve(market.address, 1);
      await market.createMarketItem(true, post.address, 1, auctionPrice, 1, ethers.constants.AddressZero);
      const itemId = ethers.utils.solidityKeccak256(['address', 'uint256', 'uint256', 'address'], [post.address, 1, 1, signer.address]);
      await market.cancelMarketItem(itemId);
      
      let priceWithFee = auctionPrice.mul(marketFee.add(10000)).div(10000);
      await expect(market.connect(account1).purchaseItem(itemId, 1, ethers.constants.AddressZero, { value: priceWithFee })).to.be.reverted;
      // book item
      const name = await book.name();
      const tokenId = 11111;

      await book.create(signer.address,tokenId,0,"", 0x0);
      expect(await book.mint(account1.address,tokenId,100,0x0)).to.be;
    });

    // it("Should revert to delete with wrong params", async () => {
    //   const [account0, account1, account2] = await ethers.getSigners();
    //   await post.mint(signer.address, "Maxim's first post");
    //   await post.approve(market.address, 1);
    //   await market.createMarketItem(true, post.address, 1, auctionPrice, 1, ethers.constants.AddressZero, { value: listingFee });
    //   const itemId = ethers.utils.solidityKeccak256(['address', 'uint256', 'uint256', 'address'], [post.address, 1, 1, signer.address]);
    //   const wrongItemId = ethers.utils.solidityKeccak256(['address', 'uint256', 'uint256', 'address'], [post.address, 2, 1, signer.address]);
    //   //not a correct post item id
    //   await expect(market.cancelMarketItem(wrongItemId)).to.be.revertedWith("Marketplace: Item is not listed at all");
    //   //not approved to market now
    //   // await post.approve(market.address, 1);
    //   // await expect(market.cancelMarketItem(itemId)).to.be.revertedWith("Marketplace: Token is not approved.");
    //   //not owner
    //   // await post.approve(market.address, 1);
    //   await expect(market.connect(account1).cancelMarketItem(itemId)).to.be.revertedWith("Marketplace: Market item can't be cancelled from other then seller or market owner. Aborting.");
    //   await post.transferFrom(account0.address, account1.address, 1);
    //   await expect(market.cancelMarketItem(itemId)).to.be.revertedWith("Marketplace: Not owner of the token");
    // });


    // it("Should seller, buyer and market owner correct MATIC value after sale", async () => {
    //   const [account0, account1, account2] = await ethers.getSigners();
    //   const marketOwnerBalance = await ethers.provider.getBalance(account0.address);
    //   await post.mint(account1.address, "Alice's first post");
    //   await post.connect(account1).approve(market.address, 1);
    //   //create market item
    //   let sellerBal = await ethers.provider.getBalance(account1.address);
    //   let listingFeeRecipientBal = await ethers.provider.getBalance(listingFeeRecipient);
    //   let txresponse = await market.connect(account1).createMarketItem(true, post.address, 1, auctionPrice, 1, ethers.constants.AddressZero, { value: listingFee });
    //   const listingFeeRecipientBalAfterlisting = await ethers.provider.getBalance(listingFeeRecipient);
    //   const itemId = ethers.utils.solidityKeccak256(['address', 'uint256', 'uint256', 'address'], [post.address, 1, 1, account1.address]);

    //   const sellerBalAfterSale = await ethers.provider.getBalance(account1.address);

    //   let txreceipt = await txresponse.wait();
    //   let gas = txreceipt.gasUsed.mul(txreceipt.effectiveGasPrice);

    //   //sellerBalAfterSale = sellerBal - listingFee - gas
    //   expect(sellerBalAfterSale).to.equal(sellerBal.sub(listingFee).sub(gas));
    //   //listing fee recipient balance
    //   expect(listingFeeRecipientBalAfterlisting).to.equal(listingFeeRecipientBal.add(listingFee));
    //   //purchase
    //   const buyerBalance = await ethers.provider.getBalance(account2.address);
    //   txresponse = await market.connect(account2).purchaseItem(itemId, 1, ethers.constants.AddressZero, { value: auctionPrice });

    //   txreceipt = await txresponse.wait();
    //   const buyerBalAfterSale = await ethers.provider.getBalance(account2.address);
    //   console.log(buyerBalAfterSale);
    //   gas = txreceipt.gasUsed.mul(txreceipt.effectiveGasPrice);
    //   //buyerBalAfterSale = buyerBalance - auctionPrice - gas
    //   expect(buyerBalAfterSale).to.equal(buyerBalance.sub(auctionPrice).sub(gas));

    // });

  });



});
