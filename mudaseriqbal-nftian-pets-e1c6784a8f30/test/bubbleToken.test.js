// ganache-cli --fork https://data-seed-prebsc-1-s1.binance.org:8545 -a 10 -l 80000000 -e 1000000
// truffle test 'test/bubbleToken.test.js' --network test

const { BN, time, expectRevert } = require('@openzeppelin/test-helpers');
const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const { assert } = require('chai');

const BubbleToken = artifacts.require('BubbleToken');
let bt;

contract('bubbleToken', ([owner, minter, bob]) => {
  before(async () => {
    bt = await BubbleToken.new(minter);
  });

  it('should send mint token by minter', async () => {
    await expectRevert(bt.mint(bob, 1000), 'Caller is not a minter');
    await bt.mint(bob, 1000, { from: minter });
    assert.equal(Number(await bt.balanceOf(bob)), 1000);
  });

  it('should transferFrom success', async () => {});
});
