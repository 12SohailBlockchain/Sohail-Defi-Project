// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./BubbleToken.sol";
import "./interfaces/IBubbleNFT.sol";
import "./interfaces/IBubbleMarketplace.sol";

// BubbleFarm is the master of Bubble. He can make Bubble and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once Bubble is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract BubblePool is Ownable, IERC721Receiver {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  // Info of each user.
  struct UserInfo {
    uint256 tokenCount; // total number of tokens staked
    uint256 currentInvestmentId;
  }

  struct UserDetailInfo {
    uint256 investmentId;
    uint256 lastRewardTime;
    uint256 stakedTime;
    uint256 tokenId; //
    uint256 hashRate;
    uint256 bubbles;
    bool withdraw;
  }

  struct HashRateInfo {
    uint256 bubbles;
    uint256 hashRate;
    bool registered;
  }

  uint256 public constant NOMINATOR = 10000;
  // The Bubble TOKEN!
  BubbleToken public bubble;
  IBubbleNFT public bubbleNFT;
  IBubbleMarketplace public marketplace;
  uint256 public hashRateDivider = 1000 * 1e18;
  uint256 public maxNFTStake = 8;
  uint256 public totalAges = 4;
  uint256 public totalHashRate;
  uint256 public totalBubbles;
  uint256 public hashRateInfoCounter;
  uint256 public rewardPercentage;

  mapping(uint256 => HashRateInfo) public hashRateInfo;
  mapping(uint256 => uint256) public ageReward;

  // Info of each user that stakes LP tokens.
  mapping(address => UserInfo) public userInfo;
  mapping(address => mapping(uint256 => UserDetailInfo)) public userDetailInfo;

  event Deposit(address indexed user, uint256 indexed investmentId, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed investmentId, uint256 amount);
  event UpgradeHashrate(address indexed user, uint256 indexed investmentId, uint256 bubbles, uint256 hashRate);
  event ClaimReward(address indexed user, uint256 indexed investmentId, uint256 reward);

  /**
   * @dev Only executed on deployment time
   * @param _bubble Address of bubble token
   * @param _bubbleNFT Address of bubble NFT Token
   * @param _marketplace Address of marketplace
   * @param _rewardPercentage Initial reward percentage
   */
  constructor(
    BubbleToken _bubble,
    IBubbleNFT _bubbleNFT,
    IBubbleMarketplace _marketplace,
    uint256 _rewardPercentage
  ) {
    bubble = _bubble;
    bubbleNFT = _bubbleNFT;
    marketplace = _marketplace;
    rewardPercentage = _rewardPercentage;
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
   * @dev View function to get age
   * @param _user Address of user
   * @param _investmentId Investment Id of user
   */
  function getAge(address _user, uint256 _investmentId) public view returns (uint256) {
    UserDetailInfo memory userDetail = userDetailInfo[_user][_investmentId];
    uint256 age = (block.timestamp - userDetail.stakedTime) / 90 days;
    if (age > totalAges) age = totalAges;
    return age;
  }

  /**
   * @dev View function to see pending bubbles on frontend.
   * @param _user Address of user
   * @param _investmentId Investment Id of user
   */
  function pendingBubble(address _user, uint256 _investmentId) external view returns (uint256) {
    // UserInfo memory user = userInfo[_user];
    UserDetailInfo memory userDetail = userDetailInfo[_user][_investmentId];
    require(userDetail.withdraw == false, "token is not staked");
    uint256 totalRewardTime = block.timestamp - userDetail.lastRewardTime;
    uint256 ageRewardPercentage = ageReward[getAge(_user, _investmentId)];
    uint256 hashRate = userDetail.hashRate + ((userDetail.hashRate * ageRewardPercentage) / NOMINATOR);

    uint256 reward = ((hashRate * (rewardPercentage)) / NOMINATOR) * (totalRewardTime / 1 days);
    return reward;
  }

  /**
   * @dev Upgrade hash Rate.
   * @param _hashRateInfoId Id of hash rate info
   * @param _investmentId Investment Id of user
   */
  function upgradeHashRate(uint256 _hashRateInfoId, uint256 _investmentId) external {
    address sender = _msgSender();
    // UserInfo storage user = userInfo[sender];
    HashRateInfo memory hashRateInfo_ = hashRateInfo[_hashRateInfoId];
    require(hashRateInfo_.registered == true, "not registered");
    UserDetailInfo storage userDetail = userDetailInfo[sender][_investmentId];
    totalHashRate = totalHashRate + hashRateInfo_.hashRate;
    totalBubbles = totalBubbles + hashRateInfo_.bubbles;
    userDetail.hashRate = userDetail.hashRate + hashRateInfo_.hashRate;
    userDetail.bubbles = userDetail.bubbles + hashRateInfo_.bubbles;

    bubble.transferFrom(sender, address(this), hashRateInfo_.bubbles);
    emit UpgradeHashrate(sender, _investmentId, hashRateInfo_.bubbles, hashRateInfo_.hashRate);
  }

  /**
   * @dev Deposit NFT Id.
   * @param _tokenId Token id
   */
  function deposit(uint256 _tokenId) public {
    address sender = _msgSender();
    UserInfo storage user = userInfo[sender];
    require(user.tokenCount < maxNFTStake, "limit reached");

    UserDetailInfo storage userDetail = userDetailInfo[sender][user.currentInvestmentId];
    (address owner, uint256 hashRate) = marketplace.getEggInfo(_tokenId);
    require(owner == sender, "sender is not token owner");
    bubbleNFT.transferNft(sender, address(this), _tokenId);

    userDetail.lastRewardTime = block.timestamp;
    userDetail.stakedTime = block.timestamp;
    userDetail.tokenId = _tokenId;
    userDetail.investmentId = user.currentInvestmentId;

    userDetail.hashRate = hashRate; //come from NFT contract
    totalHashRate = totalHashRate + hashRate;
    user.tokenCount = user.tokenCount + 1;
    user.currentInvestmentId = user.currentInvestmentId + 1;

    emit Deposit(sender, user.currentInvestmentId, userDetail.hashRate);
  }

  /**
   * @dev Deposit NFT Id.
   * @param _tokenId Token id
   * @param _investmentId Investment Id of user
   */
  function withdraw(uint256 _tokenId, uint256 _investmentId) external {
    address sender = _msgSender();
    UserInfo storage user = userInfo[sender];
    UserDetailInfo storage userDetail = userDetailInfo[sender][_investmentId];
    require(userDetail.tokenId == _tokenId, "Invalid token id");
    require(userDetail.withdraw == false, "token is not staked");
    user.tokenCount = user.tokenCount - 1;
    totalHashRate = totalHashRate - userDetail.hashRate;
    totalBubbles = totalBubbles - userDetail.bubbles;
    userDetail.withdraw = true;

    bubbleNFT.transferNft(address(this), sender, _tokenId);
    claimReward(_tokenId, _investmentId);
    if (userDetail.bubbles > 0) {
      safeBubbleTransfer(sender, userDetail.bubbles);
    }
    emit Withdraw(sender, _investmentId, userDetail.hashRate);
  }

  /**
   * @dev Claim reward for user
   * @param _tokenId Token id
   * @param _investmentId Investment Id of user
   */
  function claimReward(uint256 _tokenId, uint256 _investmentId) public {
    address sender = _msgSender();
    UserDetailInfo storage userDetail = userDetailInfo[sender][_investmentId];
    require(userDetail.tokenId == _tokenId, "Invalid token id");
    require(userDetail.withdraw == false, "token is not staked");
    uint256 ageRewardPercentage = ageReward[getAge(sender, _investmentId)];
    uint256 hashRate = userDetail.hashRate + ((userDetail.hashRate * ageRewardPercentage) / NOMINATOR);
    uint256 totalRewardDays = (block.timestamp - userDetail.lastRewardTime) / 1 days;
    uint256 reward = ((hashRate * rewardPercentage) / NOMINATOR) * totalRewardDays;
    userDetail.lastRewardTime = userDetail.hashRate + (totalRewardDays * 1 days);
    bubble.mint(sender, reward);

    emit ClaimReward(sender, reward, _investmentId);
  }

  /**
   * @dev Safe Bubble transfer function, just in case if rounding error causes pool to not have enough Bubbles.
   * @param _to Address of recipient
   * @param _amount Total amount to transfer
   */
  function safeBubbleTransfer(address _to, uint256 _amount) internal {
    uint256 bubbleBal = bubble.balanceOf(address(this));
    if (_amount > bubbleBal) {
      bubble.transfer(_to, bubbleBal);
    } else {
      bubble.transfer(_to, _amount);
    }
  }

  /**
   * @dev Add or update hash rate info only by admin
   * @param _id Id of hash rate info
   * @param _bubble Total bubbles in hash rate
   * @param _hashRate Total hash rate
   * @param _registered Registration of hash rate info
   */
  function addHashRateInfoId(
    uint256 _id,
    uint256 _bubble,
    uint256 _hashRate,
    bool _registered
  ) external onlyOwner {
    if (_id == 0) {
      //new id
      hashRateInfoCounter++;
      hashRateInfo[hashRateInfoCounter] = HashRateInfo(_bubble, _hashRate, _registered);
    } else {
      hashRateInfo[_id] = HashRateInfo(_bubble, _hashRate, _registered);
    }
  }

  /**
   * @dev update hash rate divider only by admin
   * @param _hashRateDivider hash rate divider
   */
  function updateHashRateDivider(uint256 _hashRateDivider) external onlyOwner {
    hashRateDivider = _hashRateDivider;
  }

  /**
   * @dev Update max NFT Stake
   * @param _maxStake Maximum NFT Stake
   */
  function updateMaxNFTStake(uint256 _maxStake) external onlyOwner {
    maxNFTStake = _maxStake;
  }

  /**
   * @dev Update reward Percentage only by admin
   * @param _rewardPercentage Percentage reward
   */
  function updateRewardPercentage(uint256 _rewardPercentage) external onlyOwner {
    rewardPercentage = _rewardPercentage;
  }

  /**
   * @dev Update age reward percentage only by admin
   * @param _ageId Should start from 1 upto total ages
   * @param _rewardPercentage Percentage reward
   */
  function updateAgeRewardPercentage(uint256 _ageId, uint256 _rewardPercentage) external onlyOwner {
    ageReward[_ageId] = _rewardPercentage;
  }

  /**
   * @dev Update total ages
   * @param _totalAges Total ages
   */
  function updateTotalAges(uint256 _totalAges) external onlyOwner {
    totalAges = _totalAges;
  }
}
