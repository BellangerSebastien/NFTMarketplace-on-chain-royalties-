// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IPostNFT is IERC721 {
    function safeTransfer(
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    function mint(address to, string memory tokenDetails)
        external
        returns (bool);

    function tokenURI(uint256 tokenId) external returns (string memory);

    function setTokenURI(uint256 tokenId, string memory _uri)
        external
        returns (bool);

    function setURIBase(string memory _uri) external returns (bool);

    function totalSupply() external view returns (uint256);
}
