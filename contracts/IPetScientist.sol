// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IPetScientist {
  function randomGenes(uint256 rand) external returns(uint256);
  function mixGenes(uint256 rand, uint256 g1, uint256 g2) external returns(uint256);

  function incubationCooldown() external returns(uint);
  function breedingCooldown() external returns(uint);
  function explorationCooldown() external returns(uint);
  function trainingCooldown() external returns(uint);

  function getLevelUpExp(uint level) external pure returns(uint);
  function getLevelUpExpense(uint level) external pure returns(uint);
  function getTrainingExp(uint level) external pure returns(uint);
  function getExplorationExp(uint level) external pure returns(uint);
  function getExplorationIncome(uint level) external pure returns(uint);
}
