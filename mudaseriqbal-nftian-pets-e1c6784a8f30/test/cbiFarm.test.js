// ganache-cli --fork https://data-seed-prebsc-1-s1.binance.org:8545 -a 10 -l 80000000 -e 1000000
// truffle test 'test/bubbleToken.test.js' --network test

const { BN, time, expectRevert } = require('@openzeppelin/test-helpers');
const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const { assert } = require('chai');

const MaviaToken = artifacts.require('MaviaToken');
let mt;

contract('CBFIFarm', (accounts) => {
  before(async () => {
    mt = await deployProxy(MaviaToken, [L1CustomGateway, L1GatewayRouter], {
      initializer: '__MaviaToken_init',
    });
  });

  it('should send coin corremtly', async () => {});

  it('should transferFrom success', async () => {});
});
