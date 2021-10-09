
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IInGameCurrency is IERC20 {
  function mint(address account, uint amount) external;
  function burnFrom(address account, uint256 amount) external;
}

interface ERC20Mintable is IERC20 {
  function mint(address account, uint amount) external;
}

interface ERC721Mintable {
  function mint(address account) external;
}
