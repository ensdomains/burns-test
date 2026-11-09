// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "../token/ERC20.sol";

/// @notice Recovery of tokens that reach a contract by mistake. Inheriting contracts decide who
/// may call it.
abstract contract Rescuable {
    event Rescued(address indexed token, address indexed to, uint256 amount);

    function rescue(ERC20 token, address to, uint256 amount) public virtual {
        require(token.transfer(to, amount), "Rescuable: transfer failed");
        emit Rescued(address(token), to, amount);
    }
}
