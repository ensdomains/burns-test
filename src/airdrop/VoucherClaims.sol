// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "../token/ERC20.sol";

/// @notice HBR airdrop. An off-chain signer issues one voucher per eligible account; each voucher
/// can be redeemed once.
contract VoucherClaims {
    event Claimed(address indexed account, uint256 amount);

    ERC20 public immutable token;
    address public immutable signer;

    mapping(bytes32 => bool) public redeemed;

    constructor(ERC20 token_, address signer_) {
        token = token_;
        signer = signer_;
    }

    function voucherDigest(address account, uint256 amount) public view returns (bytes32) {
        bytes32 inner = keccak256(abi.encode(block.chainid, address(this), account, amount));
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", inner));
    }

    function claim(address account, uint256 amount, bytes calldata signature) external {
        bytes32 voucherId = keccak256(signature);
        require(!redeemed[voucherId], "VoucherClaims: already redeemed");
        require(_recover(voucherDigest(account, amount), signature) == signer, "VoucherClaims: bad signature");
        redeemed[voucherId] = true;
        require(token.transfer(account, amount), "VoucherClaims: transfer failed");
        emit Claimed(account, amount);
    }

    function _recover(bytes32 digest, bytes calldata signature) internal pure returns (address) {
        require(signature.length == 65, "VoucherClaims: bad signature length");
        bytes32 r = bytes32(signature[0:32]);
        bytes32 s = bytes32(signature[32:64]);
        uint8 v = uint8(signature[64]);
        require(v == 27 || v == 28, "VoucherClaims: bad v");
        address recovered = ecrecover(digest, v, r, s);
        require(recovered != address(0), "VoucherClaims: invalid signature");
        return recovered;
    }
}
