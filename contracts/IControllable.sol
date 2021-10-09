// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IControllable is IERC721 {
  function breed(address account, uint256 parent1, uint256 parent2) external;
  function explore(address account, uint id1, uint id2, uint id3) external returns(uint);
  function train(address account, uint tokenId) external;
  function levelUp(address account, uint tokenId) external;

  function getLevelUpExpFor(uint tokenId) external view returns(uint);
  function getLevelUpExpenseFor(uint tokenId) external view returns(uint);
}
