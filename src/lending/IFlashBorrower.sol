// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IFlashBorrower {
    /// @notice Called by the pool during a flash loan. Must return `CALLBACK_SUCCESS` and leave
    /// the pool approved for `amount + fee`.
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        external
        returns (bytes32);
}
