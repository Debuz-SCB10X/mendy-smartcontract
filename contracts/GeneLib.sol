// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

library GeneLib {
  uint256 private constant MAIN  = 8;
  uint256 private constant SUB   = 4;
  uint256 private constant BITS  = 6;
  uint256 private constant ALL   = MAIN * SUB;
  uint256 private constant MASK  = ((1 << BITS) - 1);

  struct Genes {
    uint8[ALL] genes;
  }

  function _encode(uint8[ALL] memory attrs) internal pure returns(uint256) {
    uint256 genes;
    for (uint256 i = 0; i < ALL; ++i) {
      genes <<= BITS;
      genes |= attrs[ALL - 1 - i];
    }
    return genes;
  }

  function _decode(uint256 genes) internal pure returns(uint8[ALL] memory) {
    uint8[ALL] memory attrs;
    for (uint256 i = 0; i < ALL; ++i) {
      attrs[i] = uint8(genes & MASK);
      genes >>= BITS;
    }
    return attrs;
  }

  function _slice(uint256 v, uint256 n, uint256 offset) internal pure returns(uint256) {
    uint256 mask = uint256((1 << n) - 1);
    return uint256((v >> offset) & mask);
  }
}
