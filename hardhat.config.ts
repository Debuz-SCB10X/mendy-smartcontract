import { task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "hardhat-deploy";
import "hardhat-gas-reporter";

import * as dotenv from "dotenv";
dotenv.config();

task("abi", "Prints abi", async (args, hre) => {
  let name = (args as (string|undefined)[])[0];
  if (name === undefined) name = "PetToken";
  const artifact = await hre.artifacts.readArtifact(name);
  console.log(JSON.stringify(artifact.abi));
});

export default {
  networks: {
    gin: {
      url: "https://gin-rpc.dbzapi.com/",
      accounts: [process.env.DEPLOYER_TEST],
    },
    bsctest: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      accounts: [process.env.DEPLOYER_TEST],
    },
    polygontest: {
      url: "https://matic-mumbai.chainstacklabs.com",
      // url: "https://rpc-mumbai.matic.today",
      // url: "https://rpc-mumbai.maticvigil.com",
      accounts: [process.env.DEPLOYER_TEST],
      gasPrice: 8000000000,
    }
  },

  namedAccounts: {
    deployer: {
      default: 0
    }
  },

  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
};
