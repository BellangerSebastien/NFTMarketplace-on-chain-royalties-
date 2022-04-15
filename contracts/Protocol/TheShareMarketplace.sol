// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../interfaces/iBookNFT.sol";
import "../interfaces/iPostNFT.sol";

import "hardhat/console.sol";

contract TheShareMarketplace is Context, ReentrancyGuard, Ownable {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using SafeMath for uint256;

    enum State {
        Active,
        Release,
        Inactive
    }

    uint256 public listingFee;
    uint256 public floorPrice;
    address private _listingFeeRecipient;

    struct MarketItem {
        bytes32 itemId;
        bool isErc721;
        address nftContract;
        uint256 tokenId;
        address erc20address;
        address payable seller;
        address payable buyer;
        uint256 amount;
        uint256 price;
        State state;
    }

    mapping(bytes32 => MarketItem) private marketItemsListed;
    EnumerableSet.Bytes32Set private _openItems;

    event MarketItemUpdated(
        bytes32 itemId,
        bool indexed isErc721,
        address indexed nftContract,
        uint256 indexed tokenId,
        address erc20address,
        uint256 amount,
        uint256 price
    );

    event MarketItemCancelled(bytes32 itemId);

    modifier isForSale(bytes32 itemId) {
        require(
            marketItemsListed[itemId].state == State.Active,
            "Item is not active to be sold"
        );
        _;
    }

    constructor(
        address _recipient,
        uint256 _listingFee,
        uint256 _floorPrice
    ) {
        _listingFeeRecipient = _recipient;
        listingFee = _listingFee;
        floorPrice = _floorPrice;
    }

    function getListingFeeRecipient() public view virtual returns (address) {
        return _listingFeeRecipient;
    }

    function getMarketItem(bytes32 itemId)
        public
        view
        virtual
        returns (MarketItem memory)
    {
        return marketItemsListed[itemId];
    }

    function setListingFee(uint256 _listingFee) public virtual onlyOwner {
        listingFee = _listingFee;
    }

    function setListingFeeRecipient(address _recipient)
        public
        virtual
        onlyOwner
    {
        _listingFeeRecipient = _recipient;
    }

    function setFloorPrice(uint256 _floorPrice) public onlyOwner {
        floorPrice = _floorPrice;
    }

    function getOpenItems() public view virtual returns (bytes32[] memory) {
        return _openItems.values();
    }

    /* Places an item for sale on the marketplace */
    function createMarketItem(
        bool isErc721,
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 amount,
        address erc20address
    ) public payable nonReentrant {
        bytes32 _itemId = keccak256(
            abi.encodePacked(nftContract, tokenId, amount, _msgSender())
        );
        // if (marketItemsListed[_itemId].itemId == _itemId)
        //     revert("Marketplace: Item already exists for the current id");

        if (!isErc721) {
            require(amount > 0);
            require(
                IBookNFT(nftContract).balanceOf(_msgSender(), tokenId) >=
                    amount,
                "Marketplace: Not sufficient balance for the seller"
            );
            require(
                IBookNFT(nftContract).isApprovedForAll(
                    _msgSender(),
                    address(this)
                ),
                "Marketplace: Token is not approved."
            );
        } else {
            require(amount == 1);
            require(
                IPostNFT(nftContract).ownerOf(tokenId) == _msgSender(),
                "Marketplace: Not token owner"
            );
            require(
                IPostNFT(nftContract).isApprovedForAll(
                    _msgSender(),
                    address(this)
                ),
                "Marketplace: Token is not approved."
            );
        }

        require(
            msg.value == listingFee,
            "Price must be equal to listing price"
        );

        marketItemsListed[_itemId] = MarketItem(
            _itemId,
            isErc721,
            nftContract,
            tokenId,
            erc20address,
            payable(_msgSender()),
            payable(address(0)),
            amount,
            price,
            State.Active
        );

        _openItems.add(_itemId);

        emit MarketItemUpdated(
            _itemId,
            isErc721,
            nftContract,
            tokenId,
            erc20address,
            amount,
            price
        );
        payable(_listingFeeRecipient).transfer(listingFee);
    }

    function cancelMarketItem(bytes32 itemId) public nonReentrant {
        require(
            _openItems.contains(itemId),
            "Marketplace: Item is not listed at all"
        );
        MarketItem memory item = marketItemsListed[itemId];
        require(
            item.state == State.Active,
            "Marketplace: Item must be on market"
        );
        require(
            item.seller == _msgSender() || _msgSender() == owner(),
            "Marketplace: Market item can't be cancelled from other then seller or market owner. Aborting."
        );
        if (item.isErc721) {
            if (
                IPostNFT(item.nftContract).ownerOf(item.tokenId) != _msgSender()
            ) revert("Marketplace: Not owner of the token");
        } else {
            if (
                IBookNFT(item.nftContract).balanceOf(
                    _msgSender(),
                    item.tokenId
                ) >= item.amount
            ) revert("Marketplace: Not owner of the token");
        }
        item.state = State.Inactive;
        marketItemsListed[itemId] = item;
        _openItems.remove(itemId);
        emit MarketItemCancelled(itemId);
    }

    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function purchaseItem(
        bytes32 itemId,
        uint256 amount,
        address erc20address
    ) public payable isForSale(itemId) nonReentrant {
        MarketItem memory item = marketItemsListed[itemId];
        if (item.isErc721) {
            require(amount == 1);
            require(
                IPostNFT(item.nftContract).isApprovedForAll(
                    item.seller,
                    address(this)
                ) &&
                    IPostNFT(item.nftContract).ownerOf(item.tokenId) ==
                    item.seller,
                "Token not approved nor owned"
            );
            require(
                IPostNFT(item.nftContract).ownerOf(item.tokenId) !=
                    _msgSender(),
                "Token owner not allowed"
            );
        } else {
            require(amount>0);
            require(
                amount < item.amount &&
                    IBookNFT(item.nftContract).balanceOf(
                        item.seller,
                        item.tokenId
                    ) >
                    amount,
                "Marketplace: ERC1155 insufficient balance of the token."
            );
        }
        if (item.erc20address != erc20address) {
            require(
                msg.value >= item.price.mul(amount),
                "Marketplace: Payment method is not identical"
            );
        }
        require(
            _checkRoyalties(item.nftContract),
            "Royalties are not available"
        );

        // Get amount of royalties to pays and recipient
        (address royaltiesReceiver, uint256 royaltiesAmount) = IERC2981(
            item.nftContract
        ).royaltyInfo(item.tokenId, item.price);

        if (item.erc20address == address(0)) {
            require(
                msg.value >= item.price.mul(amount),
                "Marketplace: Insufficient value paid for the item"
            );
            if (royaltiesAmount > 0) {
                payable(royaltiesReceiver).transfer(
                    royaltiesAmount.mul(amount)
                );
            }
            payable(_msgSender()).transfer(msg.value - item.price.mul(amount));
            item.seller.transfer(item.price.sub(royaltiesAmount).mul(amount));
            if (item.isErc721) {
                IPostNFT(item.nftContract).safeTransferFrom(
                    item.seller,
                    item.buyer,
                    item.tokenId
                );
            } else {
                IBookNFT(item.nftContract).safeTransferFrom(
                    item.seller,
                    item.buyer,
                    item.tokenId,
                    item.amount,
                    ""
                );
            }
        } else {
            IERC20 token = IERC20(item.erc20address);
            require(
                token.allowance(_msgSender(), address(this)) >=
                    item.price.mul(amount),
                "Marketplace: Insufficient ERC20 allowance balance for paying for the asset."
            );
            if (royaltiesAmount > 0) {
                token.transferFrom(
                    item.buyer,
                    royaltiesReceiver,
                    royaltiesAmount.mul(amount)
                );
            }
            token.transferFrom(
                item.buyer,
                item.seller,
                item.price.sub(royaltiesAmount).mul(amount)
            );
            if (item.isErc721) {
                IPostNFT(item.nftContract).safeTransferFrom(
                    item.seller,
                    item.buyer,
                    item.tokenId
                );
            } else {
                IBookNFT(item.nftContract).safeTransferFrom(
                    item.seller,
                    item.buyer,
                    item.tokenId,
                    item.amount,
                    ""
                );
            }
        }
        item.buyer = payable(_msgSender());
        if (item.isErc721) {
            item.state = State.Release;
            _openItems.remove(itemId);
        } else {
            item.amount = item.amount.sub(amount);
            if (item.amount == 0) {
                item.state = State.Release;
                _openItems.remove(itemId);
            }
        }
        marketItemsListed[itemId] = item;
        emit MarketItemUpdated(
            itemId,
            item.isErc721,
            item.nftContract,
            item.tokenId,
            item.erc20address,
            item.amount,
            item.price
        );
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
