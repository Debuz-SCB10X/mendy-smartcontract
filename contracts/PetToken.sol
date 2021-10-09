// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./utils/OpenSeaMatic.sol";

import "./IControllable.sol";
import "./IPetScientist.sol";
import "./GeneLib.sol";

contract PetToken is Context, AccessControlEnumerable, ERC721Enumerable, ERC721Burnable, ERC721Pausable, IControllable, ContextMixin, NativeMetaTransaction
{
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

  uint8 private constant STATE_IDLE       = 0;
  uint8 private constant STATE_INCUBATION = 1;
  uint8 private constant STATE_BREED      = 2;
  uint8 private constant STATE_EXPLORE    = 3;
  uint8 private constant STATE_TRAIN      = 4;

  using Strings for uint256;

  string private _URI;
  string private _suffix;

  IPetScientist _petScientist;

  struct Pet {
    uint256 genes;
    uint32 bornAt;
    uint32 recoveryAt;
    uint32 parent1;
    uint32 parent2;
    uint16 exp;
    uint8 state;
    uint8 level;
    uint8 breedCount;
  }

  Pet[] private _pets;

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

    _setupRole(MINTER_ROLE, _msgSender());
    _setupRole(PAUSER_ROLE, _msgSender());

    _mintWithGenes(_msgSender(), type(uint256).max); // pet #0
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_exists(tokenId), "URI query for nonexistent token");
    return string(abi.encodePacked(_URI, tokenId.toString(), _suffix));
  }

  function setBaseURI(string calldata uri, string calldata suffix) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _URI = uri;
    _suffix = suffix;
  }

  function setPetScientist(IPetScientist petScientist) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _petScientist = petScientist;
  }

  function bulkMint(address account, uint count) external onlyRole(MINTER_ROLE) {
    for (uint i = 0; i < count; ++i)
      mint(account);
  }

  function mint(address to) public virtual onlyRole(MINTER_ROLE) {
    _mintWithRandomGenes(to);
  }

  function mintWithGenes(address to, uint256 genes) public virtual onlyRole(MINTER_ROLE) {
    _mintWithGenes(to, genes);
  }

  function _mintWithGenes(address to, uint256 genes) private returns(uint256){
    uint256 tokenId = _pets.length;
    Pet storage c = _pets.push();
    c.genes = genes;
    c.bornAt = uint32(block.timestamp);
    if (address(_petScientist) != address(0))
      c.recoveryAt = uint32(block.timestamp + _petScientist.incubationCooldown());
    c.state = STATE_INCUBATION;
    c.level = 1;

    _safeMint(to, tokenId);

    return tokenId;
  }

  function _mintWithRandomGenes(address to) private {
    uint256 tokenId = _pets.length;
    uint256 rand = uint160(to) | (tokenId << 160);
    uint256 genes = _petScientist.randomGenes(rand);
    _mintWithGenes(to, genes);
  }

  function breed(address account, uint256 parent1, uint256 parent2) external override onlyRole(CONTROLLER_ROLE) {
    require(parent1 != parent2, "must not same ones");
    require(ownerOf(parent1) == account, "not belong to account");
    require(ownerOf(parent2) == account, "not belong to account");
    require(!_isRecovering(parent1) && !_isRecovering(parent2), "must not recovering");
    require(!_isRelative(parent1, parent2), "must not be relative");
    _breed(account, parent1, parent2);
  }

  function _isRelative(uint256 parent1, uint256 parent2) private view returns(bool) {
    Pet storage p1 = _pets[parent1];
    Pet storage p2 = _pets[parent2];
    if (p1.parent1 == 0 || p2.parent1 == 0) return false;
    if (p1.parent1 == p2.parent1 || p1.parent1 == p2.parent2) return true;
    if (p1.parent2 == p2.parent1 || p1.parent2 == p2.parent2) return true;
    if (parent1 == p2.parent1 || parent1 == p2.parent2) return true;
    if (parent2 == p1.parent1 || parent2 == p1.parent2) return true;
    return false;
  }

  function explore(address account, uint id1, uint id2, uint id3) external override onlyRole(CONTROLLER_ROLE) returns(uint) {
    require(id1 != id2 && id1 != id3 && id2 != id3, "must not same ones");
    require(ownerOf(id1) == account, "not belong to account");
    require(ownerOf(id2) == account, "not belong to account");
    require(ownerOf(id3) == account, "not belong to account");
    require(!_isRecovering(id1) && !_isRecovering(id2) && !_isRecovering(id3), "must not recovering");

    uint cooldown = _petScientist.explorationCooldown();
    Pet storage c1 = _pets[id1];
    c1.recoveryAt = uint32(block.timestamp + cooldown);
    c1.state = STATE_EXPLORE;
    Pet storage c2 = _pets[id2];
    c2.recoveryAt = uint32(block.timestamp + cooldown);
    c2.state = STATE_EXPLORE;
    Pet storage c3 = _pets[id3];
    c3.recoveryAt = uint32(block.timestamp + cooldown);
    c3.state = STATE_EXPLORE;

    // reward
    uint level = c1.level + c2.level + c3.level;
    uint exp = _petScientist.getExplorationExp(level);
    c1.exp += uint16(exp);
    c2.exp += uint16(exp);
    c3.exp += uint16(exp);
    return _petScientist.getExplorationIncome(level);
  }

  function train(address account, uint tokenId) external override onlyRole(CONTROLLER_ROLE) {
    require(ownerOf(tokenId) == account, "not belong to account");
    require(!_isRecovering(tokenId), "must not recovering");

    Pet storage c = _pets[tokenId];
    c.recoveryAt = uint32(block.timestamp + _petScientist.trainingCooldown());
    c.state = STATE_TRAIN;

    // reward
    c.exp += uint16(_petScientist.getTrainingExp(c.level));
  }

  function levelUp(address account, uint tokenId) external override onlyRole(CONTROLLER_ROLE) {
    require(ownerOf(tokenId) == account, "not belong to account");
    Pet storage c = _pets[tokenId];
    uint nextExp = _petScientist.getLevelUpExp(c.level);
    require(c.exp >= nextExp, "not enough exp");
    c.level++;
    c.exp -= uint16(nextExp);
  }

  function getLevelUpExpFor(uint tokenId) public view override returns(uint) {
    Pet storage c = _pets[tokenId];
    return _petScientist.getLevelUpExp(c.level);
  }

  function getLevelUpExpenseFor(uint tokenId) public view override returns(uint) {
    Pet storage c = _pets[tokenId];
    return _petScientist.getLevelUpExpense(c.level);
  }

  function _isRecovering(uint tokenId) private view returns(bool) {
    return _pets[tokenId].recoveryAt >= block.timestamp;
  }

  function _breed(address account, uint256 parent1, uint256 parent2) internal {
    uint cooldown = _petScientist.breedingCooldown();

    Pet storage p1 = _pets[parent1];
    p1.recoveryAt = uint32(block.timestamp + cooldown);
    p1.state = STATE_BREED;
    p1.breedCount++;

    Pet storage p2 = _pets[parent2];
    p2.recoveryAt = uint32(block.timestamp + cooldown);
    p2.state = STATE_BREED;
    p2.breedCount++;

    uint256 rand = uint160(account) | (parent1 << 160) | (parent2 << 192);
    uint256 genes = _petScientist.mixGenes(rand, p1.genes, p2.genes);
    uint256 tokenId = _mintWithGenes(account, genes);
    Pet storage c = _pets[tokenId];
    c.parent1 = uint32(parent1);
    c.parent2 = uint32(parent2);
  }

  struct PetInfo {
    GeneLib.Genes genes;
    uint32 bornAt;
    uint32 recoveryAt;
    uint32 parent1;
    uint32 parent2;
    uint16 exp;
    uint16 nextExp;
    uint8 state;
    uint8 level;
    uint8 breedCount;
  }

  function getPetInfo(uint256 tokenId) external view returns(PetInfo memory) {
    require(_exists(tokenId), "not exists");
    Pet storage c = _pets[tokenId];
    PetInfo memory info;
    info.genes.genes = GeneLib._decode(c.genes);
    info.bornAt = c.bornAt;
    info.recoveryAt = c.recoveryAt;
    info.parent1 = c.parent1;
    info.parent2 = c.parent2;
    info.exp = c.exp;
    info.nextExp = uint16(_petScientist.getLevelUpExp(c.level));
    info.state = c.state;
    info.level = c.level;
    info.breedCount = c.breedCount;
    return info;
  }

  function pause() public virtual onlyRole(PAUSER_ROLE) {
    _pause();
  }

  function unpause() public virtual onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
    // TODO: test
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControlEnumerable, IERC165, ERC721, ERC721Enumerable) returns (bool)
  {
    // TODO: test
    return super.supportsInterface(interfaceId);
  }

  // recovery
  function claimERC20(IERC20 erc20) external onlyRole(DEFAULT_ADMIN_ROLE) {
    uint256 amount = erc20.balanceOf(address(this));
    require(amount > 0, "no token");
    erc20.transfer(_msgSender(), amount);
  }

  /**
    * This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
    */
  function _msgSender() internal override view returns (address sender) {
    return ContextMixin.msgSender();
  }

  /**
  * As another option for supporting trading without requiring meta transactions, override isApprovedForAll to whitelist OpenSea proxy accounts on Matic
  */
  function isApprovedForAll(address _owner, address _operator) public override(IERC721, ERC721) view returns (bool isOperator) {
    if (_operator == address(0x58807baD0B376efc12F5AD86aAc70E78ed67deaE)) {
      return true;
    }
    
    return ERC721.isApprovedForAll(_owner, _operator);
  }
}
