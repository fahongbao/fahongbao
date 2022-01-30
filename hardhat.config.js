require("@nomiclabs/hardhat-waffle")
require("dotenv").config()

const { MNEMONIC } = process.env

module.exports = {
  defaultNetwork: 'bsc',
  networks: {
    bsc: {
      url: "https://bsc-dataseed1.binance.org",
      chainId: 56,
      accounts: {
        mnemonic: MNEMONIC,
      },
    },
    polygon: {
      url: "https://polygon-rpc.com",
      chainId: 137,
      accounts: {
        mnemonic: MNEMONIC,
      },
    },
    optimism: {
      url: 'https://mainnet.optimism.io',
      chainId: 10,
      accounts: {
        mnemonic: MNEMONIC,
      },
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.10",
        settings: {
          optimizer: {
            enabled: false,
          },
          evmVersion: "istanbul",
        },
      },
    ],
  },
}
