task("deploy:market", "Deploys NFT marketplace", async (_taskArgs, hre) => {
  const signer = hre.ethers.provider.getSigner(0);
  const marketFactory = await ethers.getContractFactory("TheShareMarketplace");
  market = await marketFactory.deploy();
  await market.deployed();
  saveFrontendFiles(market);
  //To wait 5 blocks
  await market.deployTransaction.wait(5);


  //verify smart contract code with etherscan
  await hre.run("verify:verify", {
    address: market.address,
    constructorArguments: []
  });
});

function saveFrontendFiles(token) {
  const fs = require("fs");
  const contractsDir = __dirname + "/../../src/contracts";

  if (!fs.existsSync(contractsDir)) {
    fs.mkdirSync(contractsDir);
  }

  fs.writeFileSync(
    contractsDir + "/contract-address.json",
    JSON.stringify({ Token: token.address }, undefined, 2)
  );

  const NftArtifact = artifacts.readArtifactSync("BaboonsAroundtheGlobe");

  fs.writeFileSync(
    contractsDir + "/BaboonsAroundtheGlobe.json",
    JSON.stringify(NftArtifact, null, 2)
  );

}