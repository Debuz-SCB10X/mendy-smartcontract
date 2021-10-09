// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./IPetScientist.sol";
import "./GeneLib.sol";

contract PetScientist is IPetScientist {
  uint256 private constant GENE_MAIN  = 8;
  uint256 private constant GENE_SUB   = 4;
  uint256 private constant GENE_BITS  = 6;
  uint256 private constant GENE_ALL   = GENE_MAIN * GENE_SUB;
  uint256 private constant GENE_MASK  = ((1 << GENE_BITS) - 1);

  uint256 private _seed;

  uint public override incubationCooldown = 4 minutes;
  uint public override breedingCooldown = 4 minutes;
  uint public override explorationCooldown = 1 minutes;
  uint public override trainingCooldown = 4 minutes;

  constructor(uint256 seed) {
    _seed = seed;
  }

  function randomGenes(uint256 rand) external override returns(uint256) {
    uint256 r = uint256(keccak256(abi.encodePacked(_seed, block.coinbase, rand)));
    _seed = r;

    uint8[GENE_ALL] memory attrs;

    for (uint256 i = 0; i < GENE_ALL; ++i) {
      attrs[i] = uint8(r & 15); // random 0 - 15
      r >>= GENE_BITS;
    }

    return GeneLib._encode(attrs);
  }

  function mixGenes(uint256 rand, uint256 g1, uint256 g2) external override returns(uint256) {
    uint256 r = uint256(keccak256(abi.encodePacked(_seed, block.coinbase, rand, g1, g2)));
    _seed = r;

    uint8[GENE_ALL] memory a1 = GeneLib._decode(g1);
    uint8[GENE_ALL] memory a2 = GeneLib._decode(g2);

    uint256 p = 0;
    for (uint256 i = 0; i < GENE_MAIN; ++i) {
      for (uint256 j = GENE_SUB - 1; j >= 1; --j) {
        uint256 q = p + j;
        // rearrange a1
        if ((r & 3) == 0) { // random 0-4
          uint8 t = a1[q];
          a1[q] = a1[q-1];
          a1[q-1] = t;
        }
        r >>= 2;
        // rearrange a2
        if ((r & 3) == 0) { // random 0-4
          uint8 t = a2[q];
          a2[q] = a2[q-1];
          a2[q-1] = t;
        }
        r >>= 2;
      } 
      p += GENE_SUB;
    }

    // random genes from parents
    uint8[GENE_ALL] memory offspring;
    for (uint256 i = 0; i < GENE_ALL; ++i) {
      if ((r & 1) == 0) // random 0-1
        offspring[i] = a1[i];
      else
        offspring[i] = a2[i];
      r >>= 1;
    }

    return GeneLib._encode(offspring);
  }

  function getLevelUpExp(uint level) external pure override returns(uint) {
    return 100 + level * 10;
  }

  function getLevelUpExpense(uint level) external pure override returns(uint) {
    return (5 + level) * 1 ether;
  }

  function getTrainingExp(uint level) external pure override returns(uint) {
    return 80 + level * 5;
  }

  function getExplorationExp(uint level) external pure override returns(uint) {
    return 10 + level * 4;
  }

  function getExplorationIncome(uint level) external pure override returns(uint) {
    return (10 + level) * 1 ether;
  }
}
