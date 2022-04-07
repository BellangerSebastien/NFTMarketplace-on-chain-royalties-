// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/iBookNFT.sol";
import "../interfaces/iPostNFT.sol";

import "hardhat/console.sol";


contract TheShareMarketplace is Context, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _postItemIds;
    Counters.Counter private _bookItemIds;
    Counters.Counter private _itemsSold;

    enum State {
        Active,
        Release,
        Inactive
    }

    address payable owner;
    uint256 public listingPrice = 0.025 ether;
    uint256 public floorPrice = 0.01 ether;

    struct MarketPostItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        State state;
    }

    struct MarketBookItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        // address payable owner;
        uint256 price;
        uint256 amount;
    }

    mapping(uint256 => MarketPostItem) private idToMarketPostItem;
    mapping(uint256 => MarketBookItem) private idToMarketBookItem;

    event MarketPostItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        State state
    );

    // event MarketBookItemCreated(
    //     uint256 indexed itemId,
    //     address indexed nftContract,
    //     uint256 indexed tokenId,
    //     address seller,
    //     uint256 price,
    //     uint256 amount
    // );

    modifier isPostForSale(uint256 itemId) {
        require(
            idToMarketPostItem[itemId].state == State.Active,
            "Item is not active to be sold"
        );
        _;
    }

    constructor() {
        owner = payable(_msgSender());
    }

    /* Returns the listing price of the contract */
    // function getListingPrice() public view returns (uint256) {
    //     return listingPrice;
    // }

    function setFloorPrice(uint256 _floorPrice) public {
        floorPrice = _floorPrice;
    }

    /* Places an item for sale on the marketplace */
    function createMarketPostItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) public payable nonReentrant {
        require(
            IPostNFT(nftContract).ownerOf(tokenId) == _msgSender(),
            "Not token owner"
        );

        require(price > floorPrice, "Price must be at least 0.025 MATIC");
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );

        _postItemIds.increment();
        uint256 itemId = _postItemIds.current();

        idToMarketPostItem[itemId] = MarketPostItem(
            itemId,
            nftContract,
            tokenId,
            payable(_msgSender()),
            payable(address(0)),
            price,
            State.Active
        );

        require(
            IPostNFT(nftContract).isApprovedForAll(_msgSender(), address(this)),
            "Marketplace: Token is not approved."
        );

        emit MarketPostItemCreated(
            itemId,
            nftContract,
            tokenId,
            _msgSender(),
            address(0),
            price,
            State.Active
        );
    }

    function deleteMarketPostItem(uint256 itemId) public nonReentrant {
        require(
            itemId <= _postItemIds.current(),
            "Marketplace: Invaild item ID"
        );
        require(
            idToMarketPostItem[itemId].state == State.Active,
            "Marketplace: Item must be on market"
        );
        MarketPostItem storage item = idToMarketPostItem[itemId];

        require(
            IPostNFT(item.nftContract).ownerOf(item.tokenId) == _msgSender(),
            "Marketplace: Must be token owner"
        );
        require(
            IPostNFT(item.nftContract).isApprovedForAll(
                _msgSender(),
                address(this)
            ),
            "Marketplace: Token is not approved."
        );

        item.state = State.Inactive;
    }

    /* Places a book item for sale on the marketplace */
    // function createMarketBookItem(
    //     address nftContract,
    //     uint256 tokenId,
    //     uint256 price,
    //     uint256 amount
    // ) public payable nonReentrant {
    //     require(
    //         IBookNFT(nftContract).creatorOf(tokenId) == _msgSender(),
    //         "Not token owner"
    //     );

    //     require(price > floorPrice, "Price must be at least 0.025 MATIC");
    //     require(
    //         msg.value == listingPrice,
    //         "Price must be equal to listing price"
    //     );

    //     _bookItemIds.increment();
    //     uint256 itemId = _bookItemIds.current();

    //     IBookNFT(nftContract).safeTransferFrom(
    //         _msgSender(),
    //         address(this),
    //         tokenId,
    //         amount,
    //         ""
    //     );

    //     idToMarketBookItem[itemId] = MarketBookItem(
    //         itemId,
    //         nftContract,
    //         tokenId,
    //         payable(_msgSender()),
    //         payable(address(0)),
    //         price,
    //         amount
    //     );

    // }

    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function purchasePost(uint256 itemId)
        public
        payable
        isPostForSale(itemId)
        nonReentrant
    {
        address nftContract = idToMarketPostItem[itemId].nftContract;
        uint256 price = idToMarketPostItem[itemId].price;
        uint256 tokenId = idToMarketPostItem[itemId].tokenId;
        address seller = idToMarketPostItem[itemId].seller;
        console.log("Token ID:", tokenId);
        console.log("Seller:", seller);
        require(
            IPostNFT(nftContract).isApprovedForAll(seller, address(this)) && seller == IPostNFT(nftContract).ownerOf(tokenId),
            "Token not approved nor owned"
        );
        require(
            IPostNFT(nftContract).ownerOf(tokenId) != _msgSender(),
            "Token owner not allowed"
        );
        require(
            msg.value >= price,
            "Please submit the asking price in order to complete the purchase"
        );
        require(_checkRoyalties(nftContract), "Royalties are not available");
        // Get amount of royalties to pays and recipient
        (address royaltiesReceiver, uint256 royaltiesAmount) = IERC2981(
            nftContract
        ).royaltyInfo(tokenId, price);
        if (royaltiesAmount > 0) {
            payable(royaltiesReceiver).transfer(royaltiesAmount);
        }
        idToMarketPostItem[itemId].seller.transfer(msg.value - royaltiesAmount);
        IPostNFT(nftContract).transferFrom(
            idToMarketPostItem[itemId].seller,
            _msgSender(),
            tokenId
        );
        idToMarketPostItem[itemId].owner = payable(_msgSender());
        idToMarketPostItem[itemId].state = State.Release;
        _itemsSold.increment();
        payable(owner).transfer(listingPrice);
    }

    // function purchaseBook(uint256 itemId, uint256 _amount)
    //     public
    //     payable
    //     nonReentrant
    // {
    //     address nftContract = idToMarketBookItem[itemId].nftContract;
    //     uint256 price = idToMarketBookItem[itemId].price;
    //     uint256 tokenId = idToMarketBookItem[itemId].tokenId;
    //     require(_amount <= idToMarketBookItem[itemId].amount, "Invalid amount");
    //     require(
    //         IBookNFT(nftContract).balanceOf(address(this), tokenId) >= _amount,
    //         "Not enough balance"
    //     );
    // }

    /* Returns all unsold market post items */
    function fetchMarketPostItems()
        public
        view
        returns (MarketPostItem[] memory)
    {
        uint256 itemCount = _postItemIds.current();
        uint256 unsoldItemCount = _postItemIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        MarketPostItem[] memory items = new MarketPostItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketPostItem[i + 1].owner == address(0)) {
                uint256 currentId = i + 1;
                MarketPostItem storage currentItem = idToMarketPostItem[
                    currentId
                ];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only post items that a user has purchased */
    function fetchMyPosts() public view returns (MarketPostItem[] memory) {
        uint256 totalItemCount = _postItemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketPostItem[i + 1].owner == _msgSender()) {
                itemCount += 1;
            }
        }

        MarketPostItem[] memory items = new MarketPostItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketPostItem[i + 1].owner == _msgSender()) {
                uint256 currentId = i + 1;
                MarketPostItem storage currentItem = idToMarketPostItem[
                    currentId
                ];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only post items a user has created */
    function fetchPostItemsCreated()
        public
        view
        returns (MarketPostItem[] memory)
    {
        uint256 totalItemCount = _postItemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketPostItem[i + 1].seller == _msgSender()) {
                itemCount += 1;
            }
        }

        MarketPostItem[] memory items = new MarketPostItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketPostItem[i + 1].seller == _msgSender()) {
                uint256 currentId = i + 1;
                MarketPostItem storage currentItem = idToMarketPostItem[
                    currentId
                ];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /**
     * @dev Checks if NFT contract implements the ERC-2981 interface
     * @param _contract - the address of the NFT contract to query
     * @return true if ERC-2981 interface is supported, false otherwise
     */
    function _checkRoyalties(address _contract) internal view returns (bool) {
        bool success = IERC2981(_contract).supportsInterface(
            type(IERC2981).interfaceId
        );
        return success;
    }
}
