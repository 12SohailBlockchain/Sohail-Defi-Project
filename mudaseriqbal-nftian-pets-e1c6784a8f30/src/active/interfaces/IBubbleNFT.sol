// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

/**
 * @dev Interface for interacting with the BubbleNFT contract that holds BubbleNFT beta tokens.
 */
interface IBubbleNFT {
  function transferNft(
    address _from,
    address _to,
    uint256 _tokenId
  ) external;

  function mint(address _to, uint256 _tokenId) external;
}
