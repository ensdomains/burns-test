// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HarborPeripheryFixture} from "./utils/HarborPeripheryFixture.sol";

contract RetroTest is HarborPeripheryFixture {
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function test_claimWithEitherSignatureForm() public {
        (uint8 v, bytes32 r, bytes32 s) = signRetroVoucher(alice, 400e18);
        retro.claim(alice, 400e18, abi.encodePacked(r, s, v));
        assertEq(hbr.balanceOf(alice), 400e18);

        (v, r, s) = signRetroVoucher(bob, 250e18);
        bytes32 vs = bytes32(uint256(s) | (uint256(v - 27) << 255));
        retro.claim(bob, 250e18, abi.encodePacked(r, vs));
        assertEq(hbr.balanceOf(bob), 250e18);
    }

    function test_accountClaimsOnce() public {
        (uint8 v, bytes32 r, bytes32 s) = signRetroVoucher(alice, 400e18);
        retro.claim(alice, 400e18, abi.encodePacked(r, s, v));
        vm.expectRevert("RetroClaims: already claimed");
        retro.claim(alice, 400e18, abi.encodePacked(r, s, v));
    }

    function test_rejectsOtherSignersAndAmounts() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xB0B, retro.voucherDigest(alice, 400e18));
        vm.expectRevert("RetroClaims: bad signature");
        retro.claim(alice, 400e18, abi.encodePacked(r, s, v));

        (v, r, s) = signRetroVoucher(alice, 400e18);
        vm.expectRevert("RetroClaims: bad signature");
        retro.claim(alice, 4_000e18, abi.encodePacked(r, s, v));
    }
}
