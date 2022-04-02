//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PostNFT is Ownable, ERC721Royalty {
    constructor(string memory _name, string memory _symbol, address _recipient, uint96 _royaltyAmount) ERC721(_name,_symbol) {
        setRoyalty(_recipient, _royaltyAmount);
    }

    // Value is in basis points so 10000 = 100% , 100 = 1% etc
    function setRoyalty(address _recipient, uint96 value) public {
        _setDefaultRoyalty(_recipient, value);
    }

}
