task("deploy:market", "Deploys NFT marketplace", async (_taskArgs, hre) => {
  const signer = await ethers.getSigner(0);
  const listingFeeRecipient = signer.address;

  const marketFactory = await ethers.getContractFactory("TheShareMarketplace");
  market = await marketFactory.deploy(listingFeeRecipient, ethers.utils.parseEther('0.025'), ethers.utils.parseEther('0.5'));
  await market.deployed();
  //To wait 5 blocks
  await market.deployTransaction.wait(5);


  //verify smart contract code with etherscan
  await hre.run("verify:verify", {
    address: market.address,
    constructorArguments: [listingFeeRecipient, ethers.utils.parseEther('0.025')]
  });
});

task("deploy:book", "Deploys Book NFT", async (_taskArgs, hre) => {
  const signer = await ethers.getSigner(0);
  const bookFactory = await ethers.getContractFactory("BookNFT");
  book = await bookFactory.deploy("MaximBook", "MBT", "https://theshare.io/", signer.address, 5);
  await book.deployed();
  //To wait 5 blocks
  await book.deployTransaction.wait(5);


  //verify smart contract code with etherscan
  await hre.run("verify:verify", {
    address: book.address,
    constructorArguments: ["MaximBook", "MBT", "https://theshare.io/", signer.address, 5]
  });
});

task("deploy:post", "Deploys Post NFT", async (_taskArgs, hre) => {
  const signer = await ethers.getSigner(0);
  const postFactory = await ethers.getContractFactory("PostNFT");
  post = await postFactory.deploy("MaximPost", "MPT", "https://theshare.io/", signer.address, 5);
  await post.deployed();
  //To wait 5 blocks
  await post.deployTransaction.wait(5);


  //verify smart contract code with etherscan
  await hre.run("verify:verify", {
    address: post.address,
    constructorArguments: ["MaximPost", "MPT", "https://theshare.io/", signer.address, 5]
  });
});

