//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract TheShareToken is ERC20 {
    constructor() ERC20("TheShareToken", "TST") {
        _mint(msg.sender, 100_000_000_000 * 10**18);
    }
}
