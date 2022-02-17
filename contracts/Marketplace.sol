pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./library/Governance.sol";
import "./library/Auction.sol";

contract SpyNFTMarketplace is Governance, ReentrancyGuard {
    using Auction for Auction.Data;
    using AuctionGetter for Auction.Data;
    using SafeMath for uint256;
    uint256 public auctionIndex;
    uint256 public minDuration;
    address public feeAddress;
    mapping(uint256 => Auction.Data) public auctions;
    uint256 public marketIndex;
    struct MarketData {
        IERC721 nft;
        uint256 tokenId;
        uint256 price;
        bool isSold;
        address payToken;
        address purchaser;
        address seller;
    }
    mapping(uint256 => MarketData) public markets;

    event AuctionListed(
        uint256 indexed id,
        address payToken,
        address seller,
        address nft,
        uint256 tokenId,
				uint256 duration,
        uint256 startingPrice
    );
    event Bid(
        uint256 indexed id,
        address bidder,
        address previousBidder,
        uint256 price,
        uint256 profit,
        uint256 newDuration
    );
    event NFTReceived(
        address operator,
        address from,
        uint256 tokenId,
        bytes data
    );
    event Collected(uint256 indexed id);
    event CollectedBackNFT(uint256 indexed id);
    event MarketListed(
        uint256 indexed id,
        address payToken,
        address seller,
        address nft,
        uint256 tokenId,
        uint256 price
    );
    event MarketPurchased(uint256 indexed id, address purchaser);
    event MarketCancelled(uint256 indexed id);
    event AuctionCancelled(uint256 indexed id);

    constructor() {
    }

    fallback() external {
        revert();
    }

    function setFeeAddress(address _feeAddress) external onlyGovernance {
        feeAddress = _feeAddress;
    }

    function getAuctionData(uint256 _id)
        public
        view
        returns (
            address seller,
            address lastBidder,
            address nft,
            uint256 tokenId,
            uint256 lastPrice,
            uint256 raisedAmount,
            uint256 startedAt,
            uint256 endingAt,
            uint256 status
        )
    {
        Auction.Data storage auctionData = auctions[_id];
        seller = auctionData.seller;
        lastBidder = auctionData.lastBidder;
        nft = address(auctionData.nft);
        tokenId = auctionData.tokenId;
        lastPrice = auctionData.lastPrice;
        raisedAmount = auctionData.raisedAmount;
        startedAt = auctionData.startedAt;
        endingAt = auctionData.getEndingAt();
        status = auctionData.getStatus();
    }

    // list on direct purchasing market
    function listMarket(
        address _nft,
        uint256 _tokenId,
        address _payToken,
        uint256 _price
    ) external {
        require(_tokenId != 0, "invalid token");
        IERC721(_nft).safeTransferFrom(msg.sender, address(this), _tokenId);
        marketIndex++;
        markets[marketIndex] = MarketData({
            nft: IERC721(_nft),
            tokenId: _tokenId,
            price: _price,
            isSold: false,
            payToken: _payToken,
            purchaser: address(0),
            seller: msg.sender
        });
        emit MarketListed(marketIndex, _payToken, msg.sender, _nft, _tokenId, _price);
    }

    function purchaseWithToken(uint256 _id) external nonReentrant {
        MarketData storage marketData = markets[_id];
        require(marketData.payToken != address(0), "Purchase with token is disabled");
        require(!marketData.isSold, "Purchased");

        IERC20(marketData.payToken).transferFrom(msg.sender, address(this), marketData.price);
        _completePurchase(_id);
    }

    function purchase(uint256 _id) external payable nonReentrant {
        MarketData storage marketData = markets[_id];
        require(marketData.payToken == address(0), "Purchase with BNB is disabled");
        require(!marketData.isSold, "Purchased");
        require(msg.value == marketData.price, "mismatch ETHER amount");
        _completePurchase(_id);
    }

    function cancelMarket(uint256 _id) external {
        MarketData storage marketData = markets[_id];
        require(marketData.seller == msg.sender, "only seller");
        require(!marketData.isSold, "already sold");
        marketData.nft.transferFrom(address(this), marketData.seller, marketData.tokenId);
        marketData.isSold = true;
        emit MarketCancelled(_id);
    }

    // auction listing
    function list(
        address _payToken,
        address _nft,
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _duration
    ) external {
        require(_tokenId != 0, "invalid token");
        require(_duration >= minDuration, "invalid duration");

        IERC721(_nft).safeTransferFrom(msg.sender, address(this), _tokenId);
        auctionIndex++;
        auctions[auctionIndex] = Auction.Data({
            payToken: _payToken,
            seller: msg.sender,
            lastBidder: address(0),
            lastPrice: _startingPrice,
            nft: IERC721(_nft),
            tokenId: _tokenId,
            duration: _duration,
            startedAt: block.timestamp,
            isTaken: false,
            raisedAmount: 0
        });
        emit AuctionListed(auctionIndex, _payToken, msg.sender, _nft, _tokenId, _duration, _startingPrice);
    }

    function cancelAuction(uint256 _id) external {
        Auction.Data storage auction = auctions[_id];
        require(auction.lastBidder == address(0), "already bade");
        require(auction.getStatus() == 1, "invalid status");
        require(auction.seller == msg.sender, "Only seller");
        auction.nft.safeTransferFrom(address(this), auction.seller, auction.tokenId);
        auction.isTaken = true;
        emit AuctionCancelled(_id);
    }

    function bidWithToken(uint256 _id) external nonReentrant {
        Auction.Data storage auction = auctions[_id];
        require(auction.getStatus() == 1, "invalid status");

        address payToken = auction.getPayToken();
        require(payToken != address(0), "Bid with token is disabled");
        (
            uint256 newAmount,
            ,
            uint256 previousBidderReward,
            uint256 sellerAmount
        ) = auction.getBidAmount();

        IERC20(payToken).transferFrom(msg.sender, address(this), newAmount);
        if (auction.lastBidder != address(0)) {
            IERC20(payToken).transfer(auction.lastBidder, auction.lastPrice.add(previousBidderReward));
        }
        (uint256 newDuration, address lastBidder) = auction.updateState(msg.sender, newAmount, sellerAmount);
        emit Bid(_id, msg.sender, lastBidder, newAmount, previousBidderReward, newDuration);
    }

    function bid(uint256 _id) external payable nonReentrant {
        Auction.Data storage auction = auctions[_id];
        require(auction.getStatus() == 1, "invalid status");

        address payToken = auction.getPayToken();
        require(payToken == address(0), "Bid with BNB is disabled");
        (
            uint256 newAmount,
            ,
            uint256 previousBidderReward,
            uint256 sellerAmount
        ) = auction.getBidAmount();

        require(msg.value == newAmount, "mismatch ETHER amount");
        if (previousBidderReward > 0) {
            (bool success,) = auction.lastBidder.call{value:auction.lastPrice.add(previousBidderReward)}(new bytes(0));
            require(success, 'ETH_TRANSFER_FAILED');
        }
        (uint256 newDuration, address lastBidder) = auction.updateState(msg.sender, newAmount, sellerAmount);
        emit Bid(_id, msg.sender, lastBidder, newAmount, previousBidderReward, newDuration);
    }

    function collect(uint256 _id) external {
        Auction.Data storage auction = auctions[_id];
        require(auction.getStatus() == 2, "invalid status");
        require(
            auction.lastBidder == msg.sender || auction.seller == msg.sender,
            "not authorized"
        );
        require(!auction.isTaken, "alrady collected");
        // transfer NFT to lastBidder
        auction.nft.safeTransferFrom(
            address(this),
            auction.lastBidder,
            auction.tokenId
        );

        //send sold amount to seller
        uint256 fee = auction.raisedAmount.div(100);
        uint256 amount = auction.raisedAmount.sub(fee);

        address payToken = auction.getPayToken();
        if (payToken == address(0)) {
            (bool success,) = auction.seller.call{value:amount}(new bytes(0));
            require(success, 'ETH_TRANSFER_FAILED');
            if (fee > 0) {
                (success,) = feeAddress.call{value:fee}(new bytes(0));
                require(success, 'ETH_TRANSFER_FAILED');
            }
        } else {
            IERC20(payToken).transfer(auction.seller, amount);
            if (fee > 0) {
                IERC20(payToken).transfer(feeAddress, fee);
            }
        }
        
        auction.isTaken = true;
        emit Collected(_id);
    }

    function getBackNFT(uint256 _id) external {
        Auction.Data storage auction = auctions[_id];
        require(auction.seller == msg.sender, "only seller");
        require(auction.getStatus() == 3, "invalid status");
        require(!auction.isTaken, "already taken");
        auction.nft.safeTransferFrom(
            address(this),
            auction.seller,
            auction.tokenId
        );
        auction.isTaken = true;
        emit CollectedBackNFT(_id);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes memory data
    ) public returns (bytes4) {
        //only receive the _nft staff
        if (address(this) != operator) {
            //invalid from nft
            return 0;
        }
        //success
        emit NFTReceived(operator, from, tokenId, data);
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

    function _completePurchase(uint256 _id) private {
        MarketData storage marketData = markets[_id];
        marketData.nft.safeTransferFrom(
            address(this),
            msg.sender,
            marketData.tokenId
        );
        if (marketData.payToken == address(0)) {
            // sell with BNB
            uint256 fee = marketData.price.div(100);
            uint256 amount = marketData.price.sub(fee);
            (bool success,) = marketData.seller.call{value:amount}(new bytes(0));
            require(success, 'ETH_TRANSFER_FAILED');
            if (fee > 0) {
                (success,) = feeAddress.call{value:fee}(new bytes(0));
                require(success, 'ETH_TRANSFER_FAILED');
            }
        } else {
            // sell with Token
            uint256 fee = marketData.price.div(100);
            uint256 amount = marketData.price.sub(fee);
            IERC20(marketData.payToken).transfer(marketData.seller, amount);
            if (fee > 0) {
                IERC20(marketData.payToken).transfer(feeAddress, fee);
            }
        }
        marketData.isSold = true;
        marketData.purchaser = msg.sender;
        
        emit MarketPurchased(_id, msg.sender);
    }
}