import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.18",
  networks: {
    cerium: {
      url: 'https://cerium-rpc.canxium.net',
      accounts: ["xxxxx"]
    }
  },
  etherscan: {
    apiKey: {
      cerium: "abc"
    },
    customChains: [
      {
        network: "cerium",
        chainId: 30103,
        urls: {
          apiURL: "https://cerium-explorer.canxium.net/api",
          browserURL: "https://cerium-explorer.canxium.net"
        }
      }
    ]
  }
};

export default config;