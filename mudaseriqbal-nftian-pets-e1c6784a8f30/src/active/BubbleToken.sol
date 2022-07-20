// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract BubbleToken is ERC20, ERC20Permit, ERC20Votes, AccessControl {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  constructor(address minter) ERC20("BubbleToken", "BT") ERC20Permit("BubbleToken") {
    _setupRole(MINTER_ROLE, minter);
  }

  // The functions below are overrides required by Solidity.

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override(ERC20, ERC20Votes) {
    super._afterTokenTransfer(from, to, amount);
  }

  function mint(address _to, uint256 _amount) external {
    require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
    _mint(_to, _amount);
  }

  function _mint(address _to, uint256 _amount) internal override(ERC20, ERC20Votes) {
    super._mint(_to, _amount);
  }

  function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
    super._burn(account, amount);
  }
}
