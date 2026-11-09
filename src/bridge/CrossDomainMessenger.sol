// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Stand-in for an L1<->L2 messenger, used to run both sides of the bridge on one chain.
/// Anyone may send a message; while it is delivered, `xDomainMessageSender` is the address that
/// sent it on the other side.
contract CrossDomainMessenger {
    event MessageRelayed(address indexed sender, address indexed target, bytes message);

    address private constant NO_SENDER = address(1);
    address private _xDomainMessageSender = NO_SENDER;

    function xDomainMessageSender() external view returns (address) {
        require(_xDomainMessageSender != NO_SENDER, "Messenger: no message in flight");
        return _xDomainMessageSender;
    }

    function sendMessage(address target, bytes calldata message) external {
        _xDomainMessageSender = msg.sender;
        (bool ok, bytes memory ret) = target.call(message);
        _xDomainMessageSender = NO_SENDER;
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
        emit MessageRelayed(msg.sender, target, message);
    }
}
