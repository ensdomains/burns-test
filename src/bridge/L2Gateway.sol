// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {MintableToken} from "../token/MintableToken.sol";
import {CrossDomainMessenger} from "./CrossDomainMessenger.sol";
import {L1Gateway} from "./L1Gateway.sol";

/// @notice L2 side of the HBR bridge: mints wHBR for deposits made on L1, and burns wHBR to
/// release HBR on L1.
contract L2Gateway {
    event DepositFinalized(address indexed from, address indexed to, uint256 amount);
    event WithdrawalInitiated(address indexed from, address indexed to, uint256 amount);

    MintableToken public immutable token;
    CrossDomainMessenger public immutable messenger;
    address public immutable deployer;
    address public counterpart;

    constructor(MintableToken token_, CrossDomainMessenger messenger_) {
        token = token_;
        messenger = messenger_;
        deployer = msg.sender;
    }

    function setCounterpart(address l1Gateway) external {
        require(msg.sender == deployer && counterpart == address(0), "L2Gateway: already set");
        counterpart = l1Gateway;
    }

    function finalizeDeposit(address from, address to, uint256 amount) external {
        require(msg.sender == address(messenger), "L2Gateway: not messenger");
        token.mint(to, amount);
        emit DepositFinalized(from, to, amount);
    }

    function withdraw(address to, uint256 amount) external {
        require(amount > 0, "L2Gateway: zero amount");
        token.burn(msg.sender, amount);
        messenger.sendMessage(counterpart, abi.encodeCall(L1Gateway.finalizeWithdrawal, (to, amount)));
        emit WithdrawalInitiated(msg.sender, to, amount);
    }
}
