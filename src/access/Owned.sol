// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Single-owner access control for contracts that are configured after deployment.
abstract contract Owned {
    event OwnerSet(address indexed owner);

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Owned: not owner");
        _;
    }

    function _initOwner(address owner_) internal {
        require(owner == address(0), "Owned: already set");
        require(owner_ != address(0), "Owned: zero owner");
        owner = owner_;
        emit OwnerSet(owner_);
    }
}
