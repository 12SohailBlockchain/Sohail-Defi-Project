// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "./interfaces/IBubbleNFT.sol";

contract BubbleNFT is Initializable, ERC721Upgradeable, OwnableUpgradeable, AccessControlUpgradeable, IBubbleNFT {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  function __BubbleNFT_init(string memory _name, string memory _uri) public initializer {
    __Ownable_init();
    __ERC721_init(_name, _uri);
    __AccessControl_init();
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC721Upgradeable, AccessControlUpgradeable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function mint(address _to, uint256 _tokenId) external override onlyRole(MINTER_ROLE) {
    super._mint(_to, _tokenId);
  }

  function transferNft(
    address _from,
    address _to,
    uint256 _tokenId
  ) external override {
    super.safeTransferFrom(_from, _to, _tokenId);
  }
}
