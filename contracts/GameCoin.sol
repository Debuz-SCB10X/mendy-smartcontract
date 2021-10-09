// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract GameCoin is ERC20PresetMinterPauser {
  constructor(string memory name, string memory symbol) ERC20PresetMinterPauser(name, symbol) {
  }

  // recovery
  function claimERC20(IERC20 erc20) external onlyRole(DEFAULT_ADMIN_ROLE) {
    uint256 amount = erc20.balanceOf(address(this));
    require(amount > 0, "no token");
    erc20.transfer(_msgSender(), amount);
  }
}
