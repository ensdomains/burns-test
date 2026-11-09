// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Holds ETH that bidders set aside between auctions. A deposit can be withdrawn at any
/// time, in full or in part.
contract BidEscrow {
    event Deposited(address indexed bidder, uint256 amount);
    event Withdrawn(address indexed bidder, uint256 amount);

    mapping(address => uint256) public deposits;

    function deposit() external payable {
        require(msg.value > 0, "BidEscrow: zero deposit");
        deposits[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0 && deposits[msg.sender] >= amount, "BidEscrow: exceeds deposit");
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "BidEscrow: withdrawal failed");
        deposits[msg.sender] -= amount;
        emit Withdrawn(msg.sender, amount);
    }
}
