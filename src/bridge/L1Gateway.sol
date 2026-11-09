// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "../token/ERC20.sol";
import {CrossDomainMessenger} from "./CrossDomainMessenger.sol";
import {L2Gateway} from "./L2Gateway.sol";

/// @notice L1 side of the HBR bridge: locks HBR and asks the L2 gateway to mint wHBR; releases
/// HBR when the L2 gateway reports a burn.
contract L1Gateway {
    event DepositInitiated(address indexed from, address indexed to, uint256 amount);
    event WithdrawalFinalized(address indexed to, uint256 amount);

    ERC20 public immutable token;
    CrossDomainMessenger public immutable messenger;
    address public immutable deployer;
    address public counterpart;

    constructor(ERC20 token_, CrossDomainMessenger messenger_) {
        token = token_;
        messenger = messenger_;
        deployer = msg.sender;
    }

    function setCounterpart(address l2Gateway) external {
        require(msg.sender == deployer && counterpart == address(0), "L1Gateway: already set");
        counterpart = l2Gateway;
    }

    function deposit(address to, uint256 amount) external {
        require(amount > 0, "L1Gateway: zero amount");
        require(token.transferFrom(msg.sender, address(this), amount), "L1Gateway: transfer failed");
        messenger.sendMessage(counterpart, abi.encodeCall(L2Gateway.finalizeDeposit, (msg.sender, to, amount)));
        emit DepositInitiated(msg.sender, to, amount);
    }

    function finalizeWithdrawal(address to, uint256 amount) external {
        require(
            msg.sender == address(messenger) && messenger.xDomainMessageSender() == counterpart,
            "L1Gateway: not from L2 gateway"
        );
        require(token.transfer(to, amount), "L1Gateway: transfer failed");
        emit WithdrawalFinalized(to, amount);
    }
}
