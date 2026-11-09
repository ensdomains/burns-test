// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "../token/ERC20.sol";

/// @notice Second HBR distribution. The off-chain signer issues a voucher to each eligible
/// account, and an account can claim once. Vouchers may be signed in the 65-byte or the compact
/// 64-byte form.
contract RetroClaims {
    event Claimed(address indexed account, uint256 amount);

    ERC20 public immutable token;
    address public immutable signer;

    mapping(address => bool) public claimed;

    constructor(ERC20 token_, address signer_) {
        require(signer_ != address(0), "RetroClaims: zero signer");
        token = token_;
        signer = signer_;
    }

    function voucherDigest(address account, uint256 amount) public view returns (bytes32) {
        bytes32 inner = keccak256(abi.encode(block.chainid, address(this), account, amount));
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", inner));
    }

    function claim(address account, uint256 amount, bytes calldata signature) external {
        require(!claimed[account], "RetroClaims: already claimed");
        require(_recover(voucherDigest(account, amount), signature) == signer, "RetroClaims: bad signature");
        claimed[account] = true;
        require(token.transfer(account, amount), "RetroClaims: transfer failed");
        emit Claimed(account, amount);
    }

    function _recover(bytes32 digest, bytes calldata signature) internal pure returns (address) {
        bytes32 r = bytes32(signature[0:32]);
        bytes32 s;
        uint8 v;
        if (signature.length == 65) {
            s = bytes32(signature[32:64]);
            v = uint8(signature[64]);
        } else if (signature.length == 64) {
            bytes32 vs = bytes32(signature[32:64]);
            s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            v = uint8((uint256(vs) >> 255) + 27);
        } else {
            revert("RetroClaims: bad signature length");
        }
        return ecrecover(digest, v, r, s);
    }
}
