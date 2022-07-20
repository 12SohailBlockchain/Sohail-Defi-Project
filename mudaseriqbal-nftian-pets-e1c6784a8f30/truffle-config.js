/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 *
 * trufflesuite.com/docs/advanced/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like @truffle/hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */

require('dotenv').config();
// const { decrypt } = require('./scripts_local/key_utils');
const HDWalletProvider = require('@truffle/hdwallet-provider');
const IS_MNEMONIC_ENCRYPTED = process.env.IS_MNEMONIC_ENCRYPTED === 'true';
const RAW_VALUE = process.env.MNEMONIC;
const WALLET = process.env.WALLET_ADDRESS;
const MNEMONIC = RAW_VALUE;
const INFURA_IO_KEY = process.env.INFURA_IO_KEY;
const ETHERSCANAPI_KEY = process.env.ETHERSCANAPI_KEY;
const BSCSCANAPI_KEY = process.env.BSCSCANAPI_KEY;
const POLYGON_KEY = process.env.POLYGON_KEY;
const HECOINFOAPI_KEY = process.env.HECOINFOAPI_KEY;
const FTMCANAPI_KEY = process.env.FTMCANAPI_KEY;

module.exports = {
  // Uncommenting the defaults below
  // provides for an easier quick-start with Ganache.
  // You can also follow this format for other networks;
  // see <http://truffleframework.com/docs/advanced/configuration>
  // for more details on how to specify configuration options!
  contracts_directory: './src/active',
  contracts_build_directory: './src/abis',
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */

  networks: {
    development: {
      host: '127.0.0.1',
      port: 8545,
      network_id: '*',
      websockets: true,
    },
    test: {
      host: '127.0.0.1',
      port: 8545,
      network_id: '*',
      websockets: true,
    },
    ropsten: {
      provider: () => new HDWalletProvider(MNEMONIC, `https://ropsten.infura.io/v3/${INFURA_IO_KEY}`),
      network_id: 3,
      skipDryRun: true,
      networkCheckTimeout: 90000,
      // gas: 4698712,
      gasPrice: 47000000000,
    },
    kovan: {
      provider: () => new HDWalletProvider(MNEMONIC, `https://kovan.infura.io/v3/${INFURA_IO_KEY}`),
      network_id: 42,
      skipDryRun: true,
      networkCheckTimeout: 90000,
      gas: 4698712,
      gasPrice: 2500000007,
    },
    rinkeby: {
      provider: () => new HDWalletProvider(MNEMONIC, `https://rinkeby.infura.io/v3/${INFURA_IO_KEY}`),
      network_id: 4,
      skipDryRun: true,
      networkCheckTimeout: 90000,
      // gas: 4698712,
      gasPrice: 47000000000,
    },
    // main ethereum network(mainnet)
    mainnet: {
      provider: () => new HDWalletProvider(MNEMONIC, `https://mainnet.infura.io/v3/${INFURA_IO_KEY}`),
      network_id: 1,
      skipDryRun: true,
      networkCheckTimeout: 90000,
      timeoutBlocks: 200, // # of blocks before a deployment times out  (minimum/default: 50)
      // gas: 4698712,
      gasPrice: 55000000000,
    },
    // bsc testnet
    bscTestnet: {
      provider: () => new HDWalletProvider(MNEMONIC, 'https://data-seed-prebsc-2-s3.binance.org:8545'),
      network_id: 97,
      skipDryRun: true,
      networkCheckTimeout: 90000,
      // gas: 4698712,
      gasPrice: 10000000000,
    },
    // bsc mainnet
    bscMainnet: {
      provider: () => new HDWalletProvider(MNEMONIC, 'https://bsc-dataseed.binance.org'),
      network_id: 56,
      // skipDryRun: true,
      networkCheckTimeout: 90000,
      // gas: 4698712, // can up to 100M
      gasPrice: 5000000000,
    },
    // Polygon mumbai testnet
    polygonTestnet: {
      provider: () => new HDWalletProvider(MNEMONIC, 'https://rpc-mumbai.maticvigil.com'),
      network_id: 80001,
      gasPrice: 3000000000,
    },
    // Polygon mainnet
    polygonMainnet: {
      provider: () => new HDWalletProvider(MNEMONIC, 'https://polygon-rpc.com'),
      network_id: 137,
      gasPrice: 30000000000,
    },
    // Fantom Blockchain testnet
    fantomTestnet: {
      provider: () => new HDWalletProvider(MNEMONIC, 'https://rpc.testnet.fantom.network'),
      network_id: 4002,
      gasPrice: 2000000000,
    },
    // Fantom Blockchain mainnet
    fantomMainnet: {
      provider: () => new HDWalletProvider(MNEMONIC, 'https://rpc.ftm.tools'),
      network_id: 250,
      gasPrice: 147000000000,
    },
    // HT Heco testnet
    hecoTestnet: {
      provider: () => new HDWalletProvider(MNEMONIC, 'https://http-testnet.hecochain.com'),
      network_id: 256,
      gasPrice: 1000000000,
    },
    // HT Heco mainnet
    hecoMainnet: {
      provider: () => new HDWalletProvider(MNEMONIC, 'https://http-mainnet-node.huobichain.com'),
      network_id: 128,
      gasPrice: 2500000000,
    },
    // Arbitrum rinkeby
    arbitrumRinkeby: {
      provider: () => new HDWalletProvider(MNEMONIC, 'https://rinkeby.arbitrum.io/rpc'),
      network_id: 421611,
      gas: 287853530,
    },
    // Arbitrum mainnet
    arbitrumMainnet: {
      provider: () => new HDWalletProvider(MNEMONIC, 'https://arb1.arbitrum.io/rpc'),
      network_id: 42161,
      gas: 287853530,
    },
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    timeout: 1000000000,
  },

  // Auto publish and verify contract
  plugins: ['truffle-plugin-verify', 'truffle-contract-size'],
  api_keys: {
    etherscan: ETHERSCANAPI_KEY,
    bscscan: BSCSCANAPI_KEY,
    polygonscan: POLYGON_KEY,
    hecoinfo: HECOINFOAPI_KEY,
    ftmscan: FTMCANAPI_KEY,
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: '0.8.4',
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {
        // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200,
        },
        // evmVersion: 'byzantium',
      },
    },
  },

  // Truffle DB is currently disabled by default; to enable it, change enabled: false to enabled: true
  //
  // Note: if you migrated your contracts prior to enabling this field in your Truffle project and want
  // those previously migrated contracts available in the .db directory, you will need to run the following:
  // $ truffle migrate --reset --compile-all

  db: {
    enabled: false,
  },
};
