// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "../token/ERC20.sol";
import {HarborPair} from "../amm/HarborPair.sol";
import {LendingPool} from "../lending/LendingPool.sol";
import {IFlashBorrower} from "../lending/IFlashBorrower.sol";

/// @notice Protocol keeper. Flash-borrows USDH, liquidates every unhealthy account in a batch,
/// sells the seized HBR on the pair and repays the loan. Holds a USDH buffer to cover fees and
/// slippage; profits stay here until the owner sweeps them.
contract Liquidator is IFlashBorrower {
    event BatchLiquidated(uint256 accounts, uint256 repaid, uint256 proceeds);

    LendingPool public immutable pool;
    HarborPair public immutable pair;
    ERC20 public immutable usdh;
    ERC20 public immutable hbr;
    address public immutable owner;

    constructor(LendingPool pool_, HarborPair pair_) {
        pool = pool_;
        pair = pair_;
        usdh = pool_.debtToken();
        hbr = pool_.collateralToken();
        owner = msg.sender;
    }

    /// @notice Liquidates `accounts`, skipping any that are healthy, using a flash loan of `amount`.
    function liquidateBatch(address[] calldata accounts, uint256 amount) external {
        require(msg.sender == owner, "Liquidator: not owner");
        pool.flashLoan(this, amount, abi.encode(accounts));
    }

    function onFlashLoan(address, address, uint256 amount, uint256 fee, bytes calldata data)
        external
        returns (bytes32)
    {
        require(msg.sender == address(pool), "Liquidator: not pool");
        address[] memory accounts = abi.decode(data, (address[]));

        uint256 remaining = amount;
        uint256 repaid;
        usdh.approve(address(pool), type(uint256).max);
        for (uint256 i = 0; i < accounts.length && remaining > 0; i++) {
            if (!pool.isLiquidatable(accounts[i])) continue;
            uint256 debt = pool.debtOf(accounts[i]);
            uint256 repayAmount = debt < remaining ? debt : remaining;
            pool.liquidate(accounts[i], repayAmount);
            remaining -= repayAmount;
            repaid += repayAmount;
        }

        uint256 proceeds;
        uint256 seized = hbr.balanceOf(address(this));
        if (seized > 0) {
            hbr.approve(address(pair), seized);
            proceeds = pair.swap(hbr, seized, 0, address(this));
        }

        require(usdh.balanceOf(address(this)) >= amount + fee, "Liquidator: unprofitable");
        emit BatchLiquidated(accounts.length, repaid, proceeds);
        return pool.CALLBACK_SUCCESS();
    }

    function sweep(address to, uint256 amount) external {
        require(msg.sender == owner, "Liquidator: not owner");
        require(usdh.transfer(to, amount), "Liquidator: transfer failed");
    }
}
