//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "hardhat/console.sol";

contract PostNFT is Ownable, ERC721Royalty {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;
    mapping(uint256 => PostStruct) private posts;

    string private uriBase;

    struct PostStruct {
        string PostName;
        string PostURI;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _recipient,
        uint96 _royaltyAmount
    ) ERC721(_name, _symbol) {
        setRoyalty(_recipient, _royaltyAmount);
    }

    function totalSupply() public view virtual returns (uint256) {
        return _tokenIds.current();
    }

    function _baseURI() internal view override returns (string memory) {
        return uriBase;
    }

    function setURIBase(string memory _uri) external onlyOwner returns (bool) {
        uriBase = _uri;
        return true;
    }

    function setTokenURI(uint256 tokenId, string memory _uri)
        external
        returns (bool)
    {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI query for nonexistent token"
        );
        require(
            ownerOf(tokenId) == msg.sender,
            "ERC721URIStorage: URI query for conflicting token"
        );
        posts[tokenId].PostURI = _uri;
        return true;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI query for nonexistent token"
        );
        string memory _tokenURI = posts[tokenId].PostURI;
        string memory base = _baseURI();
        return string(abi.encodePacked(base, _tokenURI));
    }

    function mint(address to, string memory tokenDetails)
        public
        virtual
        onlyOwner
        returns (bool)
    {
        _tokenIds.increment();
        uint256 tokenID = _tokenIds.current();
        posts[tokenID] = PostStruct(tokenDetails, "");
        // console.log("Token ID in smart contract: ",tokenID);
        _safeMint(to, tokenID);
        return true;
    }

    // Value is in basis points so 10000 = 100% , 100 = 1% etc
    function setRoyalty(address _recipient, uint96 _value) public onlyOwner{
        _setDefaultRoyalty(_recipient, _value);
    }

}
