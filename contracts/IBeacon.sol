// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IBeacon {
  function PeggedCurrency() external view returns(address);
  function InGameCurrency() external view returns(address);
  function PetScientist() external view returns(address);
  function Controllable() external view returns(address);
}
