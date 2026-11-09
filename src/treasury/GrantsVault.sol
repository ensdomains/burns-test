// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "../token/ERC20.sol";
import {Owned} from "../access/Owned.sol";
import {Rescuable} from "./Rescuable.sol";

/// @notice Holds the grants budget. The treasury approves grants and recipients claim them.
/// Deployed behind clones in production, so it is configured with `initialize` rather than a
/// constructor.
contract GrantsVault is Owned, Rescuable {
    event GrantApproved(address indexed recipient, uint256 amount);
    event GrantClaimed(address indexed recipient, uint256 amount);

    ERC20 public token;
    uint256 public outstanding;
    mapping(address => uint256) public granted;

    function initialize(address owner_, ERC20 token_) external {
        _initOwner(owner_);
        token = token_;
    }

    function approveGrant(address recipient, uint256 amount) external onlyOwner {
        require(amount > 0, "GrantsVault: zero amount");
        granted[recipient] += amount;
        outstanding += amount;
        require(outstanding <= token.balanceOf(address(this)), "GrantsVault: over budget");
        emit GrantApproved(recipient, amount);
    }

    function claim() external {
        uint256 amount = granted[msg.sender];
        require(amount > 0, "GrantsVault: nothing granted");
        granted[msg.sender] = 0;
        outstanding -= amount;
        require(token.transfer(msg.sender, amount), "GrantsVault: transfer failed");
        emit GrantClaimed(msg.sender, amount);
    }

    function rescue(ERC20 token_, address to, uint256 amount) public override onlyOwner {
        super.rescue(token_, to, amount);
    }
}
