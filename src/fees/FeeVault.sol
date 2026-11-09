// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "../token/ERC20.sol";

/// @notice Holds protocol fees until the treasury withdraws them. Deployed behind clones in
/// production, so it is configured with `initialize` rather than a constructor.
contract FeeVault {
    event Initialized(address indexed owner);
    event FeesWithdrawn(address indexed token, address indexed to, uint256 amount);

    address public owner;
    bool private initialized;

    modifier initializer() {
        require(!initialized, "FeeVault: already initialized");
        initialized = true;
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "FeeVault: not owner");
        _;
    }

    function initialize(address owner_) external initializer {
        require(owner_ != address(0), "FeeVault: zero owner");
        owner = owner_;
        emit Initialized(owner_);
    }

    function withdraw(ERC20 token, address to, uint256 amount) external onlyOwner {
        require(token.transfer(to, amount), "FeeVault: transfer failed");
        emit FeesWithdrawn(address(token), to, amount);
    }
}
