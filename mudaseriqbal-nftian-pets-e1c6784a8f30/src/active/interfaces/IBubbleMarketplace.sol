// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IBubbleMarketplace {
  function getEggInfo(uint256 _tokenId) external view returns (address, uint256);
}
