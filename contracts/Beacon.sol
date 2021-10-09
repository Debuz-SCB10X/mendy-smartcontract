// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import "./IBeacon.sol";

contract Beacon is AccessControlEnumerable, IBeacon {
  address public override PeggedCurrency;
  address public override InGameCurrency;
  address public override PetScientist;
  address public override Controllable;

  constructor() {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

  function setPeggedCurrency(address target) external onlyRole(DEFAULT_ADMIN_ROLE) {
    PeggedCurrency = target;
  }

  function setInGameCurrency(address target) external onlyRole(DEFAULT_ADMIN_ROLE) {
    InGameCurrency = target;
  }

  function setPetScientist(address target) external onlyRole(DEFAULT_ADMIN_ROLE) {
    PetScientist = target;
  }

  function setControllable(address target) external onlyRole(DEFAULT_ADMIN_ROLE) {
    Controllable = target;
  }
}
