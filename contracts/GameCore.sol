// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IBeacon.sol";
import "./IControllable.sol";
import "./utils/Mintable.sol";

contract GameCore is AccessControlEnumerable {
  using SafeERC20 for IERC20;

  uint private constant MINIMUM_CHARS    = 3;
  uint private constant GENERATED_ENERGY = 5;
  uint private constant CHECKIN_COOLDOWN = 23 minutes;
  uint private constant CHECKIN_AMOUNT   = 5 ether;

  mapping(address => Player) _players;

  struct Player {
    uint64 checkedInAt;
    uint64 updatedEnergyAt;
    uint8 energy;
  }

  IBeacon public beacon;

  uint public breedingFee = 2 ether;
  uint public hatchingCost = 10 ether;

  constructor() {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

  function setBeacon(IBeacon target) external onlyRole(DEFAULT_ADMIN_ROLE) {
    beacon = target;
  }

  function setBreedingFee(uint price) external onlyRole(DEFAULT_ADMIN_ROLE) {
    breedingFee = price;
  }

  function currentEnergy() external view returns(uint, uint, uint) { // current, max, next
    uint nchars = _getControllable().balanceOf(_msgSender());
    return _currentEnergy(_msgSender(), nchars);
  }

  function nextCheckInAt() external view returns(uint) {
    Player storage p = _players[_msgSender()];
    return p.checkedInAt + CHECKIN_COOLDOWN;
  }

  function checkIn() external {
    IControllable c = _getControllable();
    uint nchars = c.balanceOf(_msgSender());
    require(nchars >= 1, "need 1 character");
    Player storage p = _players[_msgSender()];
    require(p.checkedInAt + CHECKIN_COOLDOWN <= block.timestamp, "too early");
    p.checkedInAt = uint64(block.timestamp);
    _getInGameCurrency().mint(_msgSender(), CHECKIN_AMOUNT);
  }

  // TODO: remove temporary code
  function hatch() external {
    IERC20 pegged = _getPeggedCurrency();
    require(pegged.balanceOf(_msgSender()) >= hatchingCost, "not enough fee");

    ERC721Mintable c = ERC721Mintable(address(_getControllable()));
    c.mint(_msgSender());

    pegged.transferFrom(_msgSender(), address(this), hatchingCost);
  }

  function breed(uint tokenId1, uint tokenId2) external {
    IERC20 pegged = _getPeggedCurrency();
    require(pegged.balanceOf(_msgSender()) >= breedingFee, "not enough fee");
    IERC20 ingame = _getInGameCurrency();
    require(ingame.balanceOf(_msgSender()) >= 1 ether, "not enough coin");

    IControllable c = _getControllable();
    c.breed(_msgSender(), tokenId1, tokenId2);

    pegged.transferFrom(_msgSender(), address(this), breedingFee);
    ingame.transferFrom(_msgSender(), address(this), breedingFee); // breeding cost
  }

  function explore(uint tokenId1, uint tokenId2, uint tokenId3) external {
    IControllable c = _getControllable();
    uint nchars = c.balanceOf(_msgSender());
    require(nchars >= 3, "need 3 characters");
    _updateEnergy(_msgSender(), nchars, -1);

    uint income = c.explore(_msgSender(), tokenId1, tokenId2, tokenId3);
    _getInGameCurrency().mint(_msgSender(), income);
  }

  function train(uint tokenId) external {
    IControllable c = _getControllable();
    uint nchars = c.balanceOf(_msgSender());
    require(nchars >= 1, "need 1 character");
    _updateEnergy(_msgSender(), nchars, -1);

    c.train(_msgSender(), tokenId);
  }

  function levelUp(uint tokenId) external {
    IControllable c = _getControllable();
    uint expense = c.getLevelUpExpenseFor(tokenId);
    IInGameCurrency ingame = _getInGameCurrency();
    require(ingame.balanceOf(_msgSender()) >= expense, "not enough coin");

    c.levelUp(_msgSender(), tokenId);

    ingame.burnFrom(_msgSender(), expense);
  }

  function _currentEnergy(address account, uint nchars) private view returns(uint, uint, uint) {
    (uint max, uint cooldown) = _getEnergyInfo(nchars);
    if (max <= 0) return (0, 0, 0);

    Player storage p = _players[account];
    uint secondsFromUpdated = block.timestamp - p.updatedEnergyAt;
    uint generatedEnergy = (secondsFromUpdated / cooldown) * GENERATED_ENERGY;
    if (p.energy + generatedEnergy >= max) return (max, max, 0);
    uint next = p.updatedEnergyAt + ((secondsFromUpdated + (cooldown - 1)) / cooldown) * cooldown;
    return (p.energy + generatedEnergy, max, next);
  }

  function _updateEnergy(address account, uint nchars, int change) private {
    (uint max, uint cooldown) = _getEnergyInfo(nchars);
    require(max > 0, "max energy should not be 0");
    Player storage p = _players[account];
    uint secondsFromUpdated = block.timestamp - p.updatedEnergyAt;
    if (secondsFromUpdated >= 1 days) {
      p.updatedEnergyAt = uint32(block.timestamp);
      p.energy = uint8(change < 0 ? _add(max, change) : max);
      return;
    }
    uint step = secondsFromUpdated / cooldown;
    uint generatedEnergy = step * GENERATED_ENERGY;
    p.updatedEnergyAt += uint64(step * cooldown);
    uint energy;
    if (change < 0) {
      energy = p.energy + generatedEnergy;
      if (energy >= max) energy = max;
      p.energy = uint8(energy - uint(-change));
      return;
    }
    energy = p.energy + generatedEnergy + uint(change);
    if (energy >= max) energy = max;
    p.energy = uint8(energy);
  }

  function _add(uint a, int b) private pure returns(uint) {
    if (b < 0) {
      return a - uint(-b);
    }
    return a + uint(b);
  }

  function _getEnergyInfo(uint nchars) private pure returns(uint, uint) {
    if (nchars < MINIMUM_CHARS) return (0, 1 days);
    if (nchars <= 10) return (20, 6 minutes);
    if (nchars <= 20) return (40, 3 minutes);
    return (60, 2 minutes);
  }

  function _getBreedingCost(uint breedCount) private pure returns(uint) {
    
  }

  function _getPeggedCurrency() private view returns(IERC20) {
    return IERC20(beacon.PeggedCurrency());
  }

  function _getInGameCurrency() private view returns(IInGameCurrency) {
    return IInGameCurrency(beacon.InGameCurrency());
  }

  function _getControllable() private view returns(IControllable) {
    return IControllable(beacon.Controllable());
  }

  // recovery
  function claimERC20(IERC20 erc20) external onlyRole(DEFAULT_ADMIN_ROLE) {
    uint256 amount = erc20.balanceOf(address(this));
    require(amount > 0, "no token");
    erc20.transfer(_msgSender(), amount);
  }
}
