require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("hardhat-gas-reporter");
require("tasks");
const { config } = require("dotenv");
const { resolve } = require("path")

require




// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

config({ path: resolve(__dirname, "./.env") });

const mnemonic = process.env.MNEMONIC;
module.exports = {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  defaultNetwork: "matic",
  networks: {
    matic: {
      accounts: {
        count: 10,
        mnemonic,
        path: "m/44'/60'/0'/0",
      },
      url: "https://rpc-mainnet.maticvigil.com",

    },
    mumbai: {
      accounts: {
        count: 10,
        mnemonic,
        path: "m/44'/60'/0'/0",
      },
      url: "https://rpc-mumbai.maticvigil.com",

    },
  },
  gasReporter: {
    enabled: (process.env.REPORT_GAS) ? true : false,
    currency: 'USD',
    coinmarketcap: process.env.COINMARKETCAP_API_KEY
  },
};
