// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/IBubbleMarketplace.sol";
import "./interfaces/IBubbleNFT.sol";
import "./libraries/VRFConsume.sol";

contract BubbleMarketplace is
  Initializable,
  OwnableUpgradeable,
  AccessControlUpgradeable,
  IERC721Receiver,
  VRFConsume,
  IBubbleMarketplace
{
  using SafeMath for uint256;
  // Structs

  // The active bid for a given token, contains the bidder, the marketplace fee at the time of the bid, and the amount of wei placed on the token
  struct BidInfo {
    uint256 bidId;
    address bidder;
    uint256 amount;
    uint256 startTime;
    uint256 endTime;
    uint256 nextBidderId;
  }

  struct BidderInfo {
    uint256 bidId;
    uint256 bidderId;
    address bidder;
    bool claimed;
  }

  struct BidWinnerInfo {
    uint256 bidId;
    address winner;
    uint256 amount;
    uint256 totalBids;
  }

  // The sale price for a given token containing the seller and the amount of wei to be sold for
  struct SaleInfo {
    address seller;
    uint256 amount;
  }

  struct EggInfo {
    uint256 tokenId;
    address owner;
    uint256 eggType;
  }
  // 1) Pearl Bubble - 1% Rarity : 100 units. ( Each unit : 1000 Hashrate )   2.5/week (20 x 2) (20 x 3)
  // 2) Honey Bubble - 3% Rarity : 300 units. ( Each unit : 875 Hashrate ) 7.5/week (20 x 7) (20 * 8)
  // 3) Electro Bubble - 6% Rarity : 600 units. ( Each unit : 750 Hashrate ) 15/week
  // 4) Frozen Bubble - 8% Rarity : 800 units. ( Each unit : 625 Hashrate ) 20/week
  // 5) Metal Bubble - 10% Rarity : 1000 units. ( Each unit : 500 Hashrate ) 25/week
  // 6) Sky Bubble - 15% Rarity : 1500 units. ( Each unit : 375 Hashrate ) 37.5./week (20 x 37) (20 x 38)
  // 7) Breeze Bubble - 17% Rarity : 1700 units. ( Each unit : 250 Hashrate ) 42.5/week (20 x 42) (20 x 43)
  // 8) Green Bubble - 40% Rarity : 4000 units. ( Each unit : 125 Hashrate ) 100/week

  uint256 public constant EGG_PER_WEEK = 250;
  uint256 public constant EGG_TYPE_LENGTH = 8;
  uint256[] public RARITY_HASHRATE;

  mapping(uint256 => EggInfo) public eggInfo;

  // IBubbleNFT contract
  IBubbleNFT public bubbleNft;
  // erc1155 contract
  IERC721Upgradeable public erc721;
  IERC20Upgradeable public cBFIToken;
  // ChainLink
  uint internal vrfFee;
  bytes32 internal vrfKeyHash;
  bytes32 internal vrfRequestId;

  // Mapping from erc721 contract to mapping of tokenId to sale price.
  mapping(uint256 => mapping(address => SaleInfo)) public saleInfo;

  mapping(uint256 => mapping(address => mapping(uint256 => mapping(uint256 => BidderInfo)))) private bidderInfo;

  mapping(uint256 => mapping(address => mapping(uint256 => BidWinnerInfo))) private bidWinnerInfo;

  // Mapping of erc721 contract to mapping of token ID to the current bid amount.
  mapping(uint256 => mapping(address => BidInfo)) private bidInfo;
  mapping(address => uint256) public bidBalance;
  mapping(uint256 => mapping(address => uint8)) private priceType;
  // A minimum increase in bid amount when out bidding someone.
  uint8 public minimumBidIncreasePercentage; // 10 = 10%

  address public adminWallet;
  uint256 public eggPrice;
  uint256 public bidId;
  uint256 public bidderId;

  uint256 public currentTokenId;
  uint256 public startBuyingEgg;

  uint256 public adminPercentage;
  uint256 public previousBiddersPercentage;
  uint256 public currentEgg;

  event Sold(address indexed _buyer, address indexed _seller, uint256 _amount, uint256 _tokenId);

  event Bid(address indexed _bidder, uint256 _amount, uint256 _tokenId, uint256 _bidId, uint256 _bidderId);

  event AcceptBid(
    address indexed _bidder,
    address indexed _seller,
    uint256 _amount,
    uint256 _tokenId,
    uint256 _bidderId
  );

  event CancelBid(address indexed _bidder, uint256 _amount, uint256 _tokenId);
  event BuyNewEgg(address indexed user, uint256 tokenId, uint256 eggType);

  /**
   * @dev Initializes the contract setting the market settings and creator royalty interfaces.
   */
  function __BubbleMarketplace_init(
    address _bubbleNft,
    address _cBFIToken,
    uint256 _eggPrice,
    uint256 _adminPercentage,
    uint256 _previousBiddersPercentage
  ) public initializer {
    __Ownable_init();
    __AccessControl_init();
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

    bubbleNft = IBubbleNFT(_bubbleNft);
    erc721 = IERC721Upgradeable(_bubbleNft);
    cBFIToken = IERC20Upgradeable(_cBFIToken);
    minimumBidIncreasePercentage = 10;
    eggPrice = _eggPrice;
    currentTokenId = 1;
    startBuyingEgg = block.timestamp;
    adminPercentage = _adminPercentage;
    previousBiddersPercentage = _previousBiddersPercentage;
    RARITY_HASHRATE = [1000, 875, 750, 625, 500, 375, 250, 125];
    adminWallet = _msgSender();
  }

  /**
   * @dev Update Chainlink VRF config
   * @param _VRFCoordinator Chainlink VRF Coordinator address
   * @param _LINKToken LINK token address
   * @param _VRFKeyHash Chainlink VRF Key Hash
   * @param _VRFFee Chainlink VRF fee
   */
  function updateVRFConfig(
    address _VRFCoordinator,
    address _LINKToken,
    bytes32 _VRFKeyHash,
    uint _VRFFee
  ) public onlyOwner {
    __VRFConsumer_init(_VRFCoordinator, _LINKToken);
    vrfKeyHash = _VRFKeyHash;
    vrfFee = _VRFFee;
  }

  /**
   * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
   * by `operator` from `from`, this function is called.
   *
   * It must return its Solidity selector to confirm the token transfer.
   * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
   *
   * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
   */
  function onERC721Received(
    address _operator,
    address,
    uint256,
    bytes calldata
  ) external view override returns (bytes4) {
    require(_operator == address(this), "self");
    return this.onERC721Received.selector;
  }

  /**
   * @dev Callback function used by VRF Coordinator
   * If your fulfillRandomness function uses more than 200k gas, the transaction will fail.
   */
  function fulfillRandomness(bytes32 _requestId, uint256 randomness) internal override {
    require(vrfRequestId == _requestId, "Wrong request id");
    uint newEgg_ = randomness % 8;
    // _setWarTeam(teamIndex_);
    _setEgg(newEgg_);
    // emit FulfillRandomnessVRF(teamIndex_);
  }

  //Read return whitelist paging
  function getEggsPaging(uint _offset, uint _limit)
    public
    view
    returns (
      EggInfo[] memory eggs,
      uint nextOffset,
      uint total
    )
  {
    uint totalEggs = currentTokenId;
    if (_limit == 0) {
      _limit = 1;
    }

    if (_limit > totalEggs - _offset) {
      _limit = totalEggs - _offset;
    }

    EggInfo[] memory values = new EggInfo[](_limit);
    for (uint i = 0; i < _limit; i++) {
      values[i] = eggInfo[_offset + i];
    }

    return (values, _offset + _limit, totalEggs);
  }

  function _setEgg(uint _egg) internal {
    currentEgg = _egg;
  }

  receive() external payable {}

  /**
   * @dev set wallet address where funds will send
   * @param _adminWallet address where funds will send
   */
  function setAdminWallet(address _adminWallet) external onlyOwner {
    adminWallet = _adminWallet;
  }

  /**
   * @dev set percentages
   * @param _adminPercentage admin percentage
   * @param _previousBiddersPercentage previous bidders percentage
   */
  function setPercentages(uint256 _adminPercentage, uint256 _previousBiddersPercentage) external onlyOwner {
    adminPercentage = _adminPercentage;
    previousBiddersPercentage = _previousBiddersPercentage;
  }

  /**
   * @dev get the token sale price against token id
   * @param _tokenId uint256 ID of the token
   * @param _owner address of the token owner
   */
  function getSalePrice(uint256 _tokenId, address _owner) external view returns (address, uint256) {
    return (saleInfo[_tokenId][_owner].seller, saleInfo[_tokenId][_owner].amount);
  }

  /**
   * @dev get the token sale price against token id
   * @param _tokenId uint256 ID of the token
   * @param _owner address of the token owner
   */
  function currentSalePrice(uint256 _tokenId, address _owner) external view returns (address, uint256) {
    return (saleInfo[_tokenId][_owner].seller, saleInfo[_tokenId][_owner].amount);
  }

  function getEggInfo(uint256 _tokenId) external view override returns (address, uint256) {
    uint256 eggType = eggInfo[_tokenId].eggType;
    uint256 hashRate = RARITY_HASHRATE[eggType = 1];
    return (eggInfo[_tokenId].owner, hashRate);
  }

  /**
   * @dev get active bid against token Id
   * @param _tokenId uint256 ID of the token
   * @param _owner address of the token owner
   */
  function getActiveBid(uint256 _tokenId, address _owner)
    external
    view
    returns (
      address,
      uint256,
      uint256,
      uint256
    )
  {
    BidInfo memory info = bidInfo[_tokenId][_owner];
    return (info.bidder, info.amount, info.startTime, info.endTime);
  }

  /**
   * @dev Admin function to withdraw market funds
   * Rules:
   * - only owner
   */
  function withdrawMarketFunds() external onlyOwner {
    payable(owner()).transfer(address(this).balance);
  }

  /**
   * @dev Checks that the token is owned by the sender
   * @param _tokenId uint256 ID of the token
   */
  function senderMustBeTokenOwner(uint256 _tokenId) internal view {
    require(erc721.ownerOf(_tokenId) == _msgSender() || eggInfo[_tokenId].owner == _msgSender(), "owner");
  }

  /**
   @dev mint new egg from market
   */
  function buyNewEgg() external {
    uint256 totalEggs = currentTokenId + 1;
    uint256 totalWeeks = ((block.timestamp - startBuyingEgg) / 1 weeks) + 1;
    address sender = _msgSender();
    require(totalEggs <= 10000, "all eggs are minted");
    require(totalEggs <= (totalWeeks * EGG_PER_WEEK), "try next week");

    // require(LINK.balanceOf(address(this)) >= vrfFee, "Not enough LINK");
    // vrfRequestId = requestRandomness(vrfKeyHash, vrfFee);
    currentEgg = random() % EGG_TYPE_LENGTH;
    cBFIToken.transferFrom(sender, adminWallet, eggPrice);
    bubbleNft.mint(sender, currentTokenId);

    eggInfo[currentTokenId] = EggInfo(currentTokenId, sender, currentEgg);
    currentTokenId = currentTokenId + 1;
    emit BuyNewEgg(sender, currentTokenId - 1, currentEgg);
  }

  // Solidity pseudo-random function:
  function random() private view returns (uint) {
    // sha3 and now have been deprecated
    return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, EGG_TYPE_LENGTH)));
    // convert hash to integer
    // players is an array of entrants
  }

  /**
   * @dev if user want to sell and auction his token
   */
  function sendToAuctionOrBuy(
    uint256 _tokenId,
    uint256 _price,
    uint8 _priceType,
    uint256 _startTime,
    uint256 _endTime
  ) external {
    require(_priceType >= 1 && _priceType <= 3, "wrong price type");
    senderMustBeTokenOwner(_tokenId);
    address sender = _msgSender();
    if (erc721.ownerOf(_tokenId) != address(this)) _transferNft(sender, address(this), _tokenId);
    priceType[_tokenId][sender] = _priceType;
    //buy
    if (_priceType == 1) {
      saleInfo[_tokenId][sender] = SaleInfo(payable(sender), _price);
    } else if (_priceType == 2) {
      //bid no time
      bidInfo[_tokenId][sender] = BidInfo(bidId, sender, _price, 0, 0, 0);
      bidId += 1;
    } else if (_priceType == 3) {
      // bid with start and end time
      bidInfo[_tokenId][sender] = BidInfo(bidId, sender, _price, _startTime, _endTime, 0);
      bidId += 1;
    }
  }

  /**
   * @dev buy token if it is for sale.
   * @param _tokenId uint256 ID of the token.
   * @param _owner address of the token owner
   */
  function buy(uint256 _tokenId, address _owner) public {
    require(priceType[_tokenId][_owner] == 1, "wrong price type");
    require(eggInfo[_tokenId].owner == _owner, "not owner");
    SaleInfo memory sp = saleInfo[_tokenId][_owner];

    address sender = _msgSender();
    _transferNft(address(this), sender, _tokenId);

    uint256 toAdmin = (sp.amount * adminPercentage) / 100;

    cBFIToken.transferFrom(sender, sp.seller, sp.amount - toAdmin);
    cBFIToken.transferFrom(sender, adminWallet, toAdmin);

    saleInfo[_tokenId][_owner] = SaleInfo(payable(address(0)), 0);

    eggInfo[_tokenId].owner = sender;
    emit Sold(sender, _owner, sp.amount, _tokenId);
  }

  /**
   * @dev Bids on the token, replacing the bid if the bid is higher than the current bid. You cannot bid on a token you already own.
   * @param _newBidAmount uint256 value in wei to bid.
   * @param _tokenId uint256 ID of the token
   * @param _owner address of the token owner
   */
  function bid(
    uint256 _newBidAmount,
    uint256 _tokenId,
    address _owner
  ) external payable {
    uint8 pt = priceType[_tokenId][_owner];
    BidInfo storage currentBid = bidInfo[_tokenId][_owner];
    require(bidWinnerInfo[_tokenId][_owner][currentBid.bidId].winner == address(0), "bid is already won");

    require(pt == 2 || pt == 3, "no for bid");
    if (pt == 3) require(currentBid.startTime < block.timestamp && currentBid.endTime > block.timestamp, "wrong dates");

    uint256 currentBidAmount = currentBid.amount;
    require(
      _newBidAmount >= currentBidAmount.add(currentBidAmount.mul(minimumBidIncreasePercentage).div(100)),
      "high minimum percentage"
    );

    // Refund previous bidder.
    _refundBid(_tokenId, _owner);
    //transfer tokens to contracts
    cBFIToken.transferFrom(_msgSender(), address(this), _newBidAmount);

    bidderInfo[_tokenId][_owner][currentBid.bidId][currentBid.nextBidderId] = BidderInfo(
      bidId,
      currentBid.nextBidderId,
      _msgSender(),
      false
    );
    currentBid.nextBidderId += 1;
    // Set the new bid.
    _setBid(_newBidAmount, msg.sender, _tokenId, _owner);
    emit Bid(msg.sender, _newBidAmount, _tokenId, currentBid.bidId, currentBid.nextBidderId - 1);
  }

  /**
   * @dev Accept the bid on the token.
   * @param _tokenId uint256 ID of the token
   * @param _owner address of the token owner
   */
  function acceptBid(uint256 _tokenId, address _owner) public {
    // The sender must be the token owner
    senderMustBeTokenOwner(_tokenId);

    // Check that a bid exists.
    require(bidInfo[_tokenId][_owner].bidder != address(0), "no bid");

    BidInfo storage currentBid = bidInfo[_tokenId][_owner];

    // Transfer token.
    _transferNft(address(this), currentBid.bidder, _tokenId);

    uint256 previousBiddersAmount = (currentBid.amount * previousBiddersPercentage) / 100;
    uint256 toAdmin = (currentBid.amount * adminPercentage) / 100;
    bidWinnerInfo[_tokenId][_owner][currentBid.bidId] = BidWinnerInfo(
      currentBid.bidId,
      currentBid.bidder,
      previousBiddersAmount,
      currentBid.nextBidderId
    );
    eggInfo[_tokenId].owner = currentBid.bidder;
    cBFIToken.transfer(_owner, currentBid.amount - (previousBiddersAmount + toAdmin));
    cBFIToken.transfer(adminWallet, toAdmin);

    _resetBid(_tokenId, _owner);
    // Wipe the token price and bid.
    emit AcceptBid(currentBid.bidder, msg.sender, currentBid.amount, _tokenId, currentBid.bidId);
  }

  function claimRewardAsAPreviousBidder(
    uint256 _tokenId,
    address _owner,
    uint256 _bidId,
    uint256 _bidderId
  ) external {
    // BidInfo storage currentBid = bidInfo[_tokenId][_owner];
    BidWinnerInfo memory winnerInfo = bidWinnerInfo[_tokenId][_owner][_bidId];
    require(winnerInfo.winner != address(0), "bid is in progress");
    BidderInfo storage currentBidderInfo = bidderInfo[_tokenId][_owner][_bidId][_bidderId];
    require(currentBidderInfo.bidder == _msgSender(), "bidder invalid");
    require(currentBidderInfo.claimed == false, "already claimed");
    currentBidderInfo.claimed = true;
    uint256 amountToClaim = winnerInfo.amount / winnerInfo.totalBids;
    cBFIToken.transfer(_msgSender(), amountToClaim);
  }

  /**
   * @dev Auto approve and transfer. Default send 1 per time
   * @param _from address from
   * @param _to address receiver
   * @param _tokenId uint256 ID of the token
   */
  function _transferNft(
    address _from,
    address _to,
    uint256 _tokenId
  ) private {
    bubbleNft.transferNft(_from, _to, _tokenId);
  }

  /**
   * @dev Cancel the bid on the token.
   * @param _tokenId uint256 ID of the token.
   * @param _owner address of the token owner
   */
  function cancelBid(uint256 _tokenId, address _owner) external {
    // Check that sender has a current bid.
    require(_addressHasBidOnToken(msg.sender, _tokenId, _owner), "cant cancel");

    _refundBid(_tokenId, _owner);

    emit CancelBid(msg.sender, bidInfo[_tokenId][_owner].amount, _tokenId);
  }

  /**
   * @dev Internal function see if the given address has an existing bid on a token.
   * @param _bidder address that may have a current bid.
   * @param _tokenId uin256 id of the token.
   * @param _owner address of the token owner
   */
  function _addressHasBidOnToken(
    address _bidder,
    uint256 _tokenId,
    address _owner
  ) internal view returns (bool) {
    return bidInfo[_tokenId][_owner].bidder == _bidder;
  }

  /**
   * @dev Internal function to return an existing bid on a token to the
   *      bidder and reset bid.
   * @param _tokenId uin256 id of the token.
   * @param _owner address of the token owner
   */
  function _refundBid(uint256 _tokenId, address _owner) internal {
    BidInfo memory currentBid = bidInfo[_tokenId][_owner];
    if (currentBid.bidder == address(0) || currentBid.bidder == _owner) {
      return;
    }
    cBFIToken.transfer(currentBid.bidder, currentBid.amount);
    // _resetBid(_tokenId, _owner);
  }

  /**
   * @dev Internal function to reset bid by setting bidder and bid to 0.
   * @param _tokenId uin256 id of the token.
   * @param _owner address of the token owner
   */
  function _resetBid(uint256 _tokenId, address _owner) internal {
    // bidInfo[_tokenId][_owner].acceptBid = true;
  }

  /**
   * @dev Internal function to set a bid.
   * @param _amount uint256 value in wei to bid. Does not include marketplace fee.
   * @param _bidder address of the bidder.
   * @param _tokenId uin256 id of the token.
   * @param _owner address of the token owner
   */
  function _setBid(
    uint256 _amount,
    address _bidder,
    uint256 _tokenId,
    address _owner
  ) internal {
    // Check bidder not 0 address.
    require(_bidder != address(0), "no 0 address");

    bidInfo[_tokenId][_owner].bidder = _bidder;
    bidInfo[_tokenId][_owner].amount = _amount;
  }
}
