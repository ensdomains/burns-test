// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HarborFixture} from "./utils/HarborFixture.sol";

contract TokenTest is HarborFixture {
    function test_transfer() public {
        address alice = makeAddr("alice");
        hbr.transfer(alice, 10e18);
        assertEq(hbr.balanceOf(alice), 10e18);
    }

    function test_transferFromSpendsAllowance() public {
        address alice = makeAddr("alice");
        hbr.approve(alice, 5e18);
        vm.prank(alice);
        hbr.transferFrom(address(this), alice, 3e18);
        assertEq(hbr.allowance(address(this), alice), 2e18);
    }

    function test_permitSetsAllowance() public {
        (address owner, uint256 key) = makeAddrAndKey("owner");
        address spender = makeAddr("spender");
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 structHash = keccak256(
            abi.encode(hbr.PERMIT_TYPEHASH(), owner, spender, 100e18, hbr.nonces(owner), deadline)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", hbr.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);

        hbr.permit(owner, spender, 100e18, deadline, v, r, s);
        assertEq(hbr.allowance(owner, spender), 100e18);
    }

    function test_permitRejectsWrongSigner() public {
        (, uint256 key) = makeAddrAndKey("someoneElse");
        address owner = makeAddr("owner");
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 structHash =
            keccak256(abi.encode(hbr.PERMIT_TYPEHASH(), owner, address(this), 1, 0, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", hbr.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);

        vm.expectRevert("HBR: invalid permit");
        hbr.permit(owner, address(this), 1, deadline, v, r, s);
    }

    function test_onlyMintersMint() public {
        vm.prank(makeAddr("rando"));
        vm.expectRevert("MintableToken: not minter");
        usdh.mint(address(this), 1);
    }
}
