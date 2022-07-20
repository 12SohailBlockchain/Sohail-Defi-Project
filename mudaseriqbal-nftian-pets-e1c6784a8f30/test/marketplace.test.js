// ganache-cli --fork https://data-seed-prebsc-1-s1.binance.org:8545 -a 10 -l 80000000 -e 1000000
// truffle test 'test/marketplace.test.js' --network test

const { BN, time, expectRevert } = require('@openzeppelin/test-helpers');
const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const { assert } = require('chai');

const BubbleMarketplace = artifacts.require('BubbleMarketplace');
const BubbleNFT = artifacts.require('BubbleNFT');
const BubbleToken = artifacts.require('BubbleToken');

const MINTER_ROLE = web3.utils.keccak256('MINTER_ROLE');

const t = (v) => {
  return web3.utils.toWei(v.toString());
};

const f = (v) => {
  return Number(web3.utils.fromWei(v.toString()));
};

const createNewEgg = async (u) => {
  await cbi.approve(marketplace.address, t(1000), { from: u });
  const res = await marketplace.buyNewEgg({ from: u });
  const id = parseInt(res.logs[0].args.tokenId);
  const type = parseInt(res.logs[0].args.eggType);

  console.log(id, type);
  return [id, type];
};

let marketplace;
let nft;
let eggPrice = t(10);
contract('Marketplace', ([owner, minter, bob, eric, adam, alan, john, buyer, bidder1, bidder2]) => {
  let counter = 1;
  const createNewEggByUser = async (u) => {
    const [id, type] = await createNewEgg(u);
    assert.equal(f(await cbi.balanceOf(owner)), 10 * counter);
    assert.equal(f(await cbi.balanceOf(u)), 9990);
    assert.equal(id, counter);
    assert.equal(Number(await nft.balanceOf(u)), 1);
    assert.equal(await nft.ownerOf(id), u);
    counter++;
  };

  before(async () => {
    cbi = await BubbleToken.new(minter);
    await cbi.mint(bob, t(10000), { from: minter });
    await cbi.mint(eric, t(10000), { from: minter });
    await cbi.mint(alan, t(10000), { from: minter });
    await cbi.mint(adam, t(10000), { from: minter });
    await cbi.mint(john, t(10000), { from: minter });
    await cbi.mint(buyer, t(10000), { from: minter });
    await cbi.mint(bidder1, t(10000), { from: minter });
    await cbi.mint(bidder2, t(10000), { from: minter });

    nft = await deployProxy(BubbleNFT, ['Bubble', 'https://localhost/api'], {
      initializer: '__BubbleNFT_init',
    });

    const _VRFCoordinator = '0xa555fC018435bef5A13C6c6870a9d4C11DEC329C';
    const _LINKToken = '0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06';
    const _VRFKeyHash = '0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186';
    const _VRFFee = '100000000000000000';

    marketplace = await deployProxy(BubbleMarketplace, [nft.address, cbi.address, eggPrice, 2, 3], {
      initializer: '__BubbleMarketplace_init',
    });
    await marketplace.updateVRFConfig(_VRFCoordinator, _LINKToken, _VRFKeyHash, _VRFFee);
    await nft.grantRole(MINTER_ROLE, marketplace.address);
  });

  it('should buy egg', async () => {
    await createNewEggByUser(bob); //1
    await createNewEggByUser(eric); //2

    await createNewEggByUser(alan); //3
    await createNewEggByUser(adam); //4
    await createNewEggByUser(john); //5
  });

  it('should put on sale and buy', async () => {
    await expectRevert(marketplace.sendToAuctionOrBuy(1, t(20), 1, 0, 0, { from: eric }), 'owner');
    await nft.setApprovalForAll(marketplace.address, true, { from: bob });
    await marketplace.sendToAuctionOrBuy(1, t(20), 1, 0, 0, { from: bob });
    assert.equal(Number(await nft.balanceOf(marketplace.address)), 1);
    assert.equal(await nft.ownerOf(1), marketplace.address);

    let eggInfo = await marketplace.eggInfo(1);
    // assert.equal(eggInfo.owner, bob);
    await cbi.approve(marketplace.address, t(1000), { from: buyer });
    await expectRevert(marketplace.buy(1, eric, { from: buyer }), 'wrong price type');
    await nft.setApprovalForAll(marketplace.address, true, { from: eric });
    await marketplace.sendToAuctionOrBuy(2, t(20), 1, 0, 0, { from: eric });
    await expectRevert(marketplace.buy(1, eric, { from: buyer }), 'wrong price type');

    await marketplace.buy(1, bob, { from: buyer });
    assert.equal(f(await cbi.balanceOf(buyer)), 9980);
    assert.equal(f(await cbi.balanceOf(owner)), 50.4);
    assert.equal(f(await cbi.balanceOf(bob)), 10009.6);
    assert.equal(Number(await nft.balanceOf(buyer)), 1);
    assert.equal(await nft.ownerOf(1), buyer);
    eggInfo = await marketplace.eggInfo(1);
    assert.equal(eggInfo.owner, buyer);
  });

  it('It should put on auction and bid', async () => {
    await nft.setApprovalForAll(marketplace.address, true, { from: eric });

    console.log(await nft.ownerOf(2), bob, owner, marketplace.address);
    await marketplace.sendToAuctionOrBuy(2, t(20), 2, 0, 0, { from: eric });
    let eggInfo = await marketplace.eggInfo(2);
    await cbi.approve(marketplace.address, t(1000), { from: bidder1 });

    await expectRevert(marketplace.bid(t(21), 2, eric, { from: bidder1 }), 'high minimum percentage');

    await marketplace.bid(t(22), 2, eric, { from: bidder1 });
    assert.equal(f(await cbi.balanceOf(bidder1)), 9978);
    await cbi.approve(marketplace.address, t(1000), { from: bidder2 });
    await marketplace.bid(t(24.2), 2, eric, { from: bidder2 });
    assert.equal(f(await cbi.balanceOf(bidder1)), 10000);
    assert.equal(f(await cbi.balanceOf(bidder2)), 9975.8);

    await cbi.approve(marketplace.address, t(1000), { from: bob });
    await marketplace.bid(t(26.64), 2, eric, { from: bob });
    assert.equal(f(await cbi.balanceOf(bidder2)), 10000);
    assert.equal(f(await cbi.balanceOf(bob)), 9982.96);
    await marketplace.acceptBid(2, eric, { from: eric });
    assert.equal(f(await cbi.balanceOf(owner)), 50.9328);

    assert.equal(await nft.ownerOf(2), bob);
    eggInfo = await marketplace.eggInfo(2);
    assert.equal(eggInfo.owner, bob);
  });
});
