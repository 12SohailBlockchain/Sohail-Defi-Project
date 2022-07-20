// ganache-cli --fork https://data-seed-prebsc-1-s1.binance.org:8545 -a 10 -l 80000000 -e 1000000
// truffle test 'test/bubbleToken.test.js' --network test

const { BN, time, expectRevert } = require('@openzeppelin/test-helpers');
const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const { assert } = require('chai');

const MaviaToken = artifacts.require('MaviaToken');
let mt;

contract('bubblePool', (accounts) => {
  before(async () => {
    mt = await deployProxy(MaviaToken, [L1CustomGateway, L1GatewayRouter], {
      initializer: '__MaviaToken_init',
    });
  });

  it('should send coin corremtly', async () => {
    // Make transamtion from first account to second.
    const amount = 10;
    await mt.transfer(accounts[1], new BN(amount));

    assert.equal(
      (await mt.balanceOf(accounts[0])).toString(),
      accountOneStartingBalance.sub(new BN(amount)).toString(),
      "Amount wasn't corremtly taken from the sender"
    );
    assert.equal(
      (await mt.balanceOf(accounts[1])).toString(),
      accountTwoStartingBalance.add(new BN(amount)).toString(),
      "Amount wasn't corremtly sent to the receiver"
    );
  });

  it('should transferFrom success', async () => {
    const allowance = 10000000;
    const transferAmount = 1000000;
    const oldBalance = await mt.balanceOf(accounts[1]);
    mt.increaseAllowance(accounts[0], new BN(allowance));
    await mt.transferFrom(accounts[0], accounts[1], new BN(transferAmount));
    const balance = await mt.balanceOf(accounts[1]);

    assert.equal(balance.toString(), oldBalance.add(new BN(transferAmount)).toString());
  });
});
