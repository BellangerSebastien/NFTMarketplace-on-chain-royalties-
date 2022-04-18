const { ethers } = require("hardhat");

async function main() {
  const signer = ethers.provider.getSigner(0);
  const artifact = await hre.artifacts.readArtifact("BookNFT");
  const provider = ethers.getDefaultProvider();
  const book = new ethers.Contract("0x6B30CB240af83Ac556D3cB6D896B5E185b6a253b", artifact.abi, provider);
  
  //To create a token
  const tokenId = 1111;
  await book.connect(signer).create(signer.address, tokenId, 1000000, "", 0x0);
}


main()
  .then(() => process.exit(0))
  .catch((error) => {
      console.error(error);
      process.exit(1);
  });
  
  