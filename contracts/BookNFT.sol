//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract BookNFT is ERC1155, Ownable, ERC2981 {

    RoyaltyInfo private _royalties;

    constructor(address _recipient, uint96 _royaltyAmount) ERC1155("") {
        setRoyalty(_recipient, _royaltyAmount);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // This is just for OpenSea to find your metadata containing the royalties.
    // This metadata is about the contract and not the individual NFTs
    function contractURI() public pure returns (string memory) {
        return "";
    }

    function uri(uint256 id) public view override returns (string memory) {}

    function mint(
        address to,
        uint256 id,
        uint256 amount
    ) public onlyOwner {
        _mint(to, id, amount, "");
    }

    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) public {
        require(msg.sender == from);
        _burn(from, id, amount);
        // _resetTokenRoyalty(id);

    }

    // Value is in basis points so 10000 = 100% , 100 = 1% etc
    function setRoyalty(address _recipient, uint96 value) public {
        _setDefaultRoyalty(_recipient, value);
    }
}
