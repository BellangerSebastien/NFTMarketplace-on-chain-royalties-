// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../interfaces/iBookNFT.sol";
import "../interfaces/iPostNFT.sol";

contract TheShareAuction is Ownable, ReentrancyGuard {
    using Address for address;

    struct Auction {
        // address of the seller
        address seller;
        // address of the token to sale
        address nftAddress;
        // ID of the NFT
        uint256 tokenId;
        // if the auction is for ERC721 - true - or ERC1155 - false
        bool isErc721;
        // Block height of end of auction
        uint256 endedAt;
        // Block height, in which the auction started.
        uint256 startedAt;
        // optional - if the auction is settled in the ERC20 token or in native currency
        address erc20Address;
        // for ERC-1155 - how many tokens are for sale
        uint256 amount;
        // Ending price of the asset at the end of the auction
        uint256 endingPrice;
        // Actual highest bidder
        address bidder;
        // Actual highest bid fee included
        uint256 highestBid;
    }

    // List of all auctions id => auction.
    mapping(string => Auction) private _auctions;

    uint256 private _auctionCount = 0;

    string[] private _openAuctions;

    // in percents, what's the fee for the auction house, 1% - 100, 100% - 10000, range 1-10000 means 0.01% - 100%
    uint256 private _auctionFee;
    // recipient of the auction fee
    address private _auctionFeeRecipient;

    /**
     * @dev Emitted when new auction is created by the owner of the contract. Amount is valid only for ERC-1155 tokens
     */
    event AuctionCreated(
        bool indexed isErc721,
        address indexed nftAddress,
        uint256 indexed tokenId,
        string id,
        uint256 amount,
        address erc20Address,
        uint256 endedAt
    );

    /**
     * @dev Emitted when auction assets were bid.
     */
    event AuctionBid(address indexed buyer, uint256 indexed amount, string id);

    /**
     * @dev Emitted when auction is settled.
     */
    event AuctionSettled(string id);

    /**
     * @dev Emitted when auction was cancelled and assets were returned to the seller.
     */
    event AuctionCancelled(string id);

    receive() external payable {}

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

    constructor(uint256 fee, address feeRecipient) {
        _auctionFee = fee;
        _auctionFeeRecipient = feeRecipient;
    }

    function getAuctionFee() public view virtual returns (uint256) {
        return _auctionFee;
    }

    function getOpenAuctions() public view virtual returns (string[] memory) {
        return _openAuctions;
    }

    function getAuctionFeeRecipient() public view virtual returns (address) {
        return _auctionFeeRecipient;
    }

    function getAuction(string memory id)
        public
        view
        virtual
        returns (Auction memory)
    {
        return _auctions[id];
    }

    function setAuctionFee(uint256 fee) public virtual onlyOwner {
        require(
            _auctionCount == 0,
            "Fee can't be changed if there is ongoing auction."
        );
        _auctionFee = fee;
    }

    function setAuctionFeeRecipient(address recipient)
        public
        virtual
        onlyOwner
    {
        _auctionFeeRecipient = recipient;
    }

    /**
     * Check if the seller is the owner of the token.
     * We expect that the owner of the tokens approves the spending before he launch the auction
     * The function escrows the tokens to sell
     **/
    function _escrowTokensToSell(
        bool isErc721,
        address nftAddress,
        address seller,
        uint256 tokenId,
        uint256 amount
    ) internal view {
        if (!isErc721) {
            require(amount > 0);
            require(
                IBookNFT(nftAddress).balanceOf(seller, tokenId) >= amount,
                "ERC1155 token balance is not sufficient for the seller.."
            );
            //    IBookNFT(nftAddress).safeTransferFrom(seller,address(this),tokenId,amount,"");
        } else {
            require(
                IPostNFT(nftAddress).ownerOf(tokenId) == seller,
                "ERC721 token does not belong to the author."
            );
            //    IPostNFT(nftAddress).safeTransferFrom(seller, address(this), tokenId);
        }
    }

    /**
     * Transfer NFT from the contract to the recipient
     */
    function _transferNFT(
        bool isErc721,
        address nftAddress,
        address sender,
        address recipient,
        uint256 tokenId,
        uint256 amount
    ) internal {
        if (!isErc721) {
            IBookNFT(nftAddress).safeTransferFrom(
                sender,
                recipient,
                tokenId,
                amount,
                ""
            );
        } else {
            IPostNFT(nftAddress).safeTransferFrom(sender, recipient, tokenId);
        }
    }

    /**
     * Transfer assets locked in the highest bid to the recipient
     * @param erc20Address - if we are working with ERC20 token or native asset
     * @param amount - bid value to be distributed
     * @param recipient - where we will send the bid
     * @param settleOrReturnFee - when true, fee is send to the auction recipient, otherwise returned to the owner
     */
    function _transferAssets(
        address erc20Address,
        uint256 amount,
        address recipient,
        bool settleOrReturnFee
    ) internal {
        uint256 fee = (amount * _auctionFee) / 10000;
        if (erc20Address != address(0)) {
            if (settleOrReturnFee) {
                IERC20(erc20Address).transfer(recipient, amount - fee);
                IERC20(erc20Address).transfer(_auctionFeeRecipient, fee);
            } else {
                IERC20(erc20Address).transfer(recipient, amount);
            }
        } else {
            if (settleOrReturnFee) {
                Address.sendValue(payable(recipient), amount - fee);
                Address.sendValue(payable(_auctionFeeRecipient), fee);
            } else {
                Address.sendValue(payable(recipient), amount);
            }
        }
    }

    /**
     * @dev Create new auction of the NFT token in the marketplace.
     * @param id - ID of the auction, must be unique
     * @param isErc721 - whether the auction is for ERC721 or ERC1155 token
     * @param nftAddress - address of the NFT token
     * @param tokenId - ID of the NFT token
     * @param amount - ERC1155 only, number of tokens to sold.
     * @param erc20Address - address of the ERC20 token, which will be used for the payment. If native asset is used, this should be 0x0 address
     */
    function createAuction(
        string memory id,
        bool isErc721,
        address nftAddress,
        uint256 tokenId,
        address seller,
        uint256 amount,
        uint256 endedAt,
        address erc20Address
    ) public {
        require(
            _auctions[id].startedAt == 0,
            "Auction already existed for current auction Id"
        );
        require(
            endedAt > block.number + 5,
            "Auction must last at least 5 blocks from this block"
        );
        // check if the seller owns the tokens he wants to put on auction
        // transfer the tokens to the auction house
        _escrowTokensToSell(isErc721, nftAddress, seller, tokenId, amount);

        _auctionCount++;
        Auction memory auction = Auction(
            seller,
            nftAddress,
            tokenId,
            isErc721,
            endedAt,
            block.number,
            erc20Address,
            amount,
            0,
            address(0),
            0
        );
        _auctions[id] = auction;
        _openAuctions.push(id);
        emit AuctionCreated(
            isErc721,
            nftAddress,
            tokenId,
            id,
            amount,
            erc20Address,
            endedAt
        );
    }

    /**
     * @dev Buyer wants to buy NFT from auction. All the required checks must pass.
     * Buyer must approve spending of ERC20 tokens, which will be deducted from his account to the auction contract.
     * Contract must detect, if the bidder bid higher value thank the actual highest bid. If it's not enough, bid is not valid.
     * If bid is the highest one, previous bidders assets will be released back to him - we are aware of reentrancy attacks, but we will cover that.
     * Bid must be processed only during the validity of the auction, otherwise it's not accepted.
     * @param id - id of the auction to buy
     * @param bidValue - bid value + the auction fee
     * @param bidder - bidder of the auction, from which account the ERC20 assets will be debited
     */
    function bidForExternalBidder(
        string memory id,
        uint256 bidValue,
        address bidder
    ) public {
        Auction memory auction = _auctions[id];
        require(
            auction.erc20Address != address(0),
            "Auction must be placed for ERC20 token."
        );
        require(
            auction.endedAt > block.number,
            "Auction has already ended. Unable to process bid. Aborting."
        );
        uint256 bidWithoutFee = (bidValue / (10000 + _auctionFee)) * 10000;
        require(
            auction.endingPrice < bidWithoutFee,
            "Bid fee of the auction fee is lower than actual highest bid price. Aborting."
        );
        require(
            IERC20(auction.erc20Address).allowance(bidder, address(this)) >=
                bidValue,
            "Insufficient approval for ERC20 token for the auction bid. Aborting."
        );

        Auction memory newAuction = Auction(
            auction.seller,
            auction.nftAddress,
            auction.tokenId,
            auction.isErc721,
            auction.endedAt,
            block.number,
            auction.erc20Address,
            auction.amount,
            auction.endingPrice,
            auction.bidder,
            auction.highestBid
        );
        // reentrancy attack - we delete the auction temporarily
        delete _auctions[id];

        IERC20 token = IERC20(newAuction.erc20Address);
        if (!token.transferFrom(bidder, address(this), bidValue)) {
            revert(
                "Unable to transfer ERC20 tokens from the bidder to the Auction. Aborting"
            );
        }

        // returns the previous bid to the bidder
        if (newAuction.bidder != address(0) && newAuction.highestBid != 0) {
            _transferAssets(
                newAuction.erc20Address,
                newAuction.highestBid,
                newAuction.bidder,
                false
            );
        }

        // paid amount is on the Auction SC, we just need to update the auction status
        newAuction.endingPrice = bidWithoutFee;
        newAuction.highestBid = bidValue;
        newAuction.bidder = bidder;

        _auctions[id] = newAuction;
        emit AuctionBid(bidder, bidValue, id);
    }

    /**
     * @dev Buyer wants to buy NFT from auction. All the required checks must pass.
     * Buyer must either send ETH with this endpoint, or ERC20 tokens will be deducted from his account to the auction contract.
     * Contract must detect, if the bidder bid higher value thank the actual highest bid. If it's not enough, bid is not valid.
     * If bid is the highest one, previous bidders assets will be released back to him - we are aware of reentrancy attacks, but we will cover that.
     * Bid must be processed only during the validity of the auction, otherwise it's not accepted.
     * @param id - id of the auction to buy
     * @param bidValue - bid value + the auction fee
     */
    function bid(string memory id, uint256 bidValue) public payable {
        Auction memory auction = _auctions[id];
        uint256 bidWithoutFee = (bidValue / (10000 + _auctionFee)) * 10000;
        require(
            auction.endedAt > block.number,
            "Auction has already ended. Unable to process bid. Aborting."
        );
        require(
            auction.endingPrice < bidWithoutFee,
            "Bid fee of the auction fee is lower than actual highest bid price. Aborting."
        );
        if (auction.erc20Address == address(0)) {
            require(
                bidValue <= msg.value,
                "Wrong amount entered for the bid. Aborting."
            );
        }
        if (auction.erc20Address != address(0)) {
            require(
                IERC20(auction.erc20Address).allowance(
                    msg.sender,
                    address(this)
                ) >= bidValue,
                "Insufficient approval for ERC20 token for the auction bid. Aborting."
            );
        }

        Auction memory newAuction = Auction(
            auction.seller,
            auction.nftAddress,
            auction.tokenId,
            auction.isErc721,
            auction.endedAt,
            block.number,
            auction.erc20Address,
            auction.amount,
            auction.endingPrice,
            auction.bidder,
            auction.highestBid
        );
        // reentrancy attack - we delete the auction temporarily
        delete _auctions[id];

        if (newAuction.erc20Address != address(0)) {
            IERC20 token = IERC20(newAuction.erc20Address);
            if (!token.transferFrom(msg.sender, address(this), bidValue)) {
                revert(
                    "Unable to transfer ERC20 tokens to the Auction. Aborting"
                );
            }
        } else {
            Address.sendValue(payable(address(this)), bidValue);
        }
        // returns the previous bid to the bidder
        if (newAuction.bidder != address(0) && newAuction.highestBid != 0) {
            _transferAssets(
                newAuction.erc20Address,
                newAuction.highestBid,
                newAuction.bidder,
                false
            );
        }
        if (msg.value > bidValue) {
            Address.sendValue(payable(msg.sender), msg.value - bidValue);
        }
        // paid amount is on the Auction SC, we just need to update the auction status
        newAuction.endingPrice = bidWithoutFee;
        newAuction.highestBid = bidValue;
        newAuction.bidder = msg.sender;

        _auctions[id] = newAuction;
        emit AuctionBid(msg.sender, bidValue, id);
    }

    /**
     * Settle the already ended auction -
     */
    function settleAuction(string memory id) public payable virtual nonReentrant {
        // fee must be sent to the fee recipient
        // NFT token to the bidder
        // payout to the seller
        Auction memory auction = _auctions[id];
        require(
            auction.endedAt < block.number,
            "Auction can't be settled before it reaches the end."
        );

        bool isErc721 = auction.isErc721;
        address nftAddress = auction.nftAddress;
        uint256 amount = auction.amount;
        uint256 tokenId = auction.tokenId;
        address erc20Address = auction.erc20Address;
        uint256 highestBid = auction.highestBid;
        address bidder = auction.bidder;

        // avoid reentrancy attacks
        delete _auctions[id];

        _transferNFT(
            isErc721,
            nftAddress,
            auction.seller,
            bidder,
            tokenId,
            amount
        );
        _transferAssets(erc20Address, highestBid, auction.seller, true);
        _toRemove(id);
        _auctionCount--;
        emit AuctionSettled(id);
    }

    function _toRemove(string memory id) internal {
        for (uint256 x = 0; x < _openAuctions.length; x++) {
            if (
                keccak256(abi.encodePacked(_openAuctions[x])) ==
                keccak256(abi.encodePacked(id))
            ) {
                for (uint256 i = x; i < _openAuctions.length - 1; i++) {
                    _openAuctions[i] = _openAuctions[i + 1];
                }
                _openAuctions.pop();
            }
        }
    }

    /**
     * @dev Cancel auction - returns the NFT asset to the seller.
     * @param id - id of the auction to cancel
     */
    function cancelAuction(string memory id) public payable virtual {
        Auction memory auction = _auctions[id];
        require(
            auction.seller != address(0),
            "Auction is already settled. Aborting."
        );
        require(
            auction.seller == msg.sender || msg.sender == owner(),
            "Auction can't be cancelled from other thank seller or owner. Aborting."
        );
        // bool isErc721 = auction.isErc721;
        // address nftAddress = auction.nftAddress;
        // uint256 amount = auction.amount;
        // uint256 tokenId = auction.tokenId;
        address erc20Address = auction.erc20Address;
        uint256 highestBid = auction.highestBid;
        address bidder = auction.bidder;

        // prevent reentrancy attack
        delete _auctions[id];

        // we have assured that the reentrancy attack wont happen because we have deleted the auction from the list of auctions before we are sending the assets back
        // returns the NFT to the seller

        // returns the highest bid to the bidder
        if (bidder != address(0) && highestBid != 0) {
            _transferAssets(erc20Address, highestBid, bidder, false);
        }

        _auctionCount--;
        _toRemove(id);
        emit AuctionCancelled(id);
    }
}
