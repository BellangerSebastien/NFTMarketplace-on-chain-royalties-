// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IBookNFT is IERC1155 {
   function creatorOf(uint256 _id) external view returns (address);
}
