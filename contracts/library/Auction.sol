pragma solidity 0.8.4;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library AuctionGetter {
    using SafeMath for uint256;

    function getEndingAt(Auction.Data storage _data)
        internal
        view
        returns (uint256)
    {
        return _data.startedAt.add(_data.duration);
    }

    function getPayToken(Auction.Data storage _data)
        internal
        view
        returns (address)
    {
        return _data.payToken;
    }

    function getStatus(Auction.Data storage _data)
        internal
        view
        returns (uint256)
    {
        /*
         * 1: RUNNING;
         * 2: DEALED;
         * 3: FAILED;
         * 0: NOT RUNNING;
         */
        if (_data.startedAt == 0) return 0;
        if(_data.isTaken) return 0;
        uint256 _endingAt = _data.startedAt.add(_data.duration);
        if (block.timestamp <= _endingAt) {
            return 1;
        } else if (block.timestamp > _endingAt) {
            if (_data.lastBidder == address(0)) {
                return 3;
            } else {
                return 2;
            }
        }
        return 0;
    }
}

library Auction {
    using SafeMath for uint256;
    using AuctionGetter for Data;
    enum Status {
        OPENING,
        ENDED
    }
    struct Data {
        // Current owner of NFT
        address payToken;
        address seller;
        address lastBidder;
        IERC721 nft;
        uint256 tokenId;
        // Price (in wei) at beginning of auction
        uint256 lastPrice;
        // SPY amount raised
        uint256 raisedAmount;
        // Duration (in seconds) of auction
        uint256 duration;
        // Time when auction started
        // NOTE: 0 if this auction has been concluded
        uint256 startedAt;
        bool isTaken;
    }

    function updateState(
        Data storage _data,
        address _newBidder,
        uint256 _newPrice,
        uint256 _newRaisedAmount
    ) internal returns (uint256 newDuration, address lastBidder) {
				lastBidder = _data.lastBidder;
        _data.lastBidder = _newBidder;
        _data.lastPrice = _newPrice;
        _data.raisedAmount = _newRaisedAmount;
        if (_data.getEndingAt().sub(block.timestamp) < 1 hours) {
            _data.duration = _data.duration.add(10 minutes);
        }
        newDuration = _data.duration;
    }

    function getBidAmount(Data storage _data)
        internal
        view
        returns (
            uint256 newPrice,
            uint256 increaseAmount,
            uint256 previousBidderReward,
            uint256 sellerAmount
        )
    {
        // 10% increase
        if (_data.lastBidder == address(0)) {
            newPrice = _data.lastPrice;
            sellerAmount = newPrice;
        } else {
            uint256 bidderRewards = 0;
            if (_data.raisedAmount > 0) {
                bidderRewards = _data.lastPrice.sub(_data.raisedAmount);
            }
            increaseAmount = _data.lastPrice.div(10);
            increaseAmount = increaseAmount > 0 ? increaseAmount : 1;
            previousBidderReward = increaseAmount.mul(2).div(10);
            newPrice = _data.lastPrice.add(increaseAmount);
            sellerAmount = newPrice.sub(previousBidderReward).sub(bidderRewards);
        }
    }

    function validateBidding(Data storage _data) internal view {
        require(_data.getStatus() == 1, "auction is not opening");
    }
}