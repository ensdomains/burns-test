// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice HBR price in USDH, scaled by 1e18, posted by the protocol's reporter from off-chain
/// markets. A price older than an hour is not served.
contract ReferenceFeed {
    event PricePosted(uint256 price, uint256 updatedAt);

    uint256 public constant MAX_AGE = 1 hours;

    address public immutable reporter;
    uint256 public price;
    uint256 public updatedAt;

    constructor(address reporter_) {
        require(reporter_ != address(0), "ReferenceFeed: zero reporter");
        reporter = reporter_;
    }

    function post(uint256 price_) external {
        require(msg.sender == reporter, "ReferenceFeed: not reporter");
        require(price_ > 0, "ReferenceFeed: zero price");
        price = price_;
        updatedAt = block.timestamp;
        emit PricePosted(price_, block.timestamp);
    }

    function latest() external view returns (uint256) {
        require(updatedAt != 0 && block.timestamp - updatedAt <= MAX_AGE, "ReferenceFeed: stale");
        return price;
    }
}
