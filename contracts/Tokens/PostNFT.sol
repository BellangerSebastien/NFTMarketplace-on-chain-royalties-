//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../utils/StringUtils.sol";

contract PostNFT is Ownable, AccessControl, ERC721Royalty {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    using Counters for Counters.Counter;
    using StringUtils for address;

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
        string memory _uri,
        address _recipient,
        uint96 _royaltyAmount
    ) ERC721(_name, _symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());

        setRoyalty(_recipient, _royaltyAmount);
        uriBase = _uri;
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
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        } else {
            return string(abi.encodePacked(base, "0x", address(this).toAsciiString(), "/", tokenId));
        }
    }

    function mint(address to, string memory tokenDetails)
        public
        virtual
        onlyRole(MINTER_ROLE)
        returns (bool)
    {
        _tokenIds.increment();
        uint256 tokenID = _tokenIds.current();
        posts[tokenID] = PostStruct(tokenDetails, "");
        _safeMint(to, tokenID);
        return true;
    }

    function safeTransfer(
        address to,
        uint256 tokenId,
        bytes calldata data
    ) public virtual {
        super._safeTransfer(_msgSender(), to, tokenId, data);
    }

    function safeTransfer(address to, uint256 tokenId) public virtual {
        super._safeTransfer(_msgSender(), to, tokenId, "");
    }

    // Value is in basis points so 10000 = 100% , 100 = 1% etc
    function setRoyalty(address _recipient, uint96 _value) public onlyOwner {
        _setDefaultRoyalty(_recipient, _value);
    }

    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) public {
        require(ownerOf(tokenId)==_msgSender(),"PostNFT: Only token owner allowed.");
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Royalty, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
