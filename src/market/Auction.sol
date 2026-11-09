// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice English auction for ETH. Outbid bidders pull their refunds with `withdraw`.
contract Auction {
    event Bid(address indexed bidder, uint256 amount);
    event Refunded(address indexed bidder, uint256 amount);
    event Settled(address indexed winner, uint256 amount);

    address public immutable seller;
    uint256 public immutable endTime;

    address public highestBidder;
    uint256 public highestBid;
    bool public settled;
    mapping(address => uint256) public pendingReturns;

    constructor(address seller_, uint256 duration) {
        seller = seller_;
        endTime = block.timestamp + duration;
    }

    function bid() external payable {
        require(block.timestamp < endTime, "Auction: ended");
        require(msg.value > highestBid, "Auction: bid too low");
        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }
        highestBidder = msg.sender;
        highestBid = msg.value;
        emit Bid(msg.sender, msg.value);
    }

    function withdraw() external {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "Auction: nothing to withdraw");
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "Auction: refund failed");
        pendingReturns[msg.sender] = 0;
        emit Refunded(msg.sender, amount);
    }

    function settle() external {
        require(block.timestamp >= endTime, "Auction: not ended");
        require(!settled, "Auction: settled");
        settled = true;
        emit Settled(highestBidder, highestBid);
        if (highestBid > 0) {
            (bool ok,) = seller.call{value: highestBid}("");
            require(ok, "Auction: payout failed");
        }
    }
}
