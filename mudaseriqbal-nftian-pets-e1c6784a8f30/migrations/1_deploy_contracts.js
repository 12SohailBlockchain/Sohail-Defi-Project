/*
truffle migrate -f 1 -to 1 --network bscTestnet
truffle run verify ERC20Token GamepadProject --network bscTestnet

truffle migrate -f 2006 --to 2006 --network bscMainnet
truffle run verify GamepadProject --network bscMainnet
 */
const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const { time } = require('@openzeppelin/test-helpers');
const fromExponential = require('from-exponential');
const ethers = require('ethers');
const moment = require('moment');
const BN = web3.utils.BN;
const BubbleToken = artifacts.require('BubbleToken');
const BubbleNFT = artifacts.require('BubbleNFT');
const BubbleMarketplace = artifacts.require('BubbleMarketplace');
const MockToken = artifacts.require('MockToken');
const CBFIFarm = artifacts.require('CBFIFarm');
const BubblePool = artifacts.require('BubblePool');

const MINTER_ROLE = web3.utils.keccak256('MINTER_ROLE');

module.exports = async (deployer, network, accounts) => {
  if (network === 'test') return;
  const owner = accounts[0];
  console.log('Owner:', owner);
  await deployer.deploy(BubbleToken, owner);
  const token = await BubbleToken.deployed();
  await deployer.deploy(MockToken, web3.utils.toWei('10000000000'));
  const cbfi = await MockToken.deployed();

  await deployProxy(BubbleNFT, ['Bubbles', 'http://localhost/id'], {
    deployer: deployer,
    initializer: '__BubbleNFT_init',
  });

  const nft = await BubbleNFT.deployed();

  await deployProxy(BubbleMarketplace, [nft.address, cbfi.address, web3.utils.toWei('10'), 2, 3], {
    deployer: deployer,
    initializer: '__BubbleMarketplace_init',
  });

  const marketplace = await BubbleMarketplace.deployed();
  await deployer.deploy(CBFIFarm, cbfi.address, web3.utils.toWei('10'), 15569999);

  const farm = await CBFIFarm.deployed();

  await deployer.deploy(BubblePool, token.address, nft.address, marketplace.address, 50);

  const pool = await BubblePool.deployed();

  await nft.grantRole(MINTER_ROLE, farm.address);
  await nft.grantRole(MINTER_ROLE, pool.address);

  // const instanceBubbleToken = await BubbleToken.deployed();
};
