// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "./ERC20.sol";

/// @notice ERC-20 whose supply is managed by minters the owner appoints.
contract MintableToken is ERC20 {
    event MinterSet(address indexed minter, bool allowed);

    address public immutable owner;
    mapping(address => bool) public isMinter;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_, 18) {
        owner = msg.sender;
    }

    modifier onlyMinter() {
        require(isMinter[msg.sender], "MintableToken: not minter");
        _;
    }

    function setMinter(address minter, bool allowed) external {
        require(msg.sender == owner, "MintableToken: not owner");
        isMinter[minter] = allowed;
        emit MinterSet(minter, allowed);
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyMinter {
        _burn(from, amount);
    }
}
