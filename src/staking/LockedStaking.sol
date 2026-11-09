// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "../token/ERC20.sol";
import {RewardAccrual} from "./RewardAccrual.sol";

/// @notice Stake HBR for at least 30 days and earn USDH. Each new stake restarts the account's
/// lock.
contract LockedStaking is RewardAccrual {
    event Staked(address indexed account, uint256 amount, uint256 unlockAt);
    event Withdrawn(address indexed account, uint256 amount);
    event RewardPaid(address indexed account, uint256 reward);
    event RewardAdded(uint256 reward, uint256 periodFinish);

    uint256 public constant LOCK = 30 days;

    ERC20 public immutable stakingToken;
    ERC20 public immutable rewardToken;
    address public immutable owner;

    mapping(address => uint256) public unlockAt;

    constructor(ERC20 stakingToken_, ERC20 rewardToken_) {
        stakingToken = stakingToken_;
        rewardToken = rewardToken_;
        owner = msg.sender;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "LockedStaking: zero amount");
        _increase(msg.sender, amount);
        unlockAt[msg.sender] = block.timestamp + LOCK;
        require(
            stakingToken.transferFrom(msg.sender, address(this), amount),
            "LockedStaking: transfer failed"
        );
        emit Staked(msg.sender, amount, unlockAt[msg.sender]);
    }

    function withdraw(uint256 amount) external settle(msg.sender) {
        require(amount > 0, "LockedStaking: zero amount");
        require(block.timestamp >= unlockAt[msg.sender], "LockedStaking: locked");
        totalStaked -= amount;
        balanceOf[msg.sender] -= amount;
        require(stakingToken.transfer(msg.sender, amount), "LockedStaking: transfer failed");
        emit Withdrawn(msg.sender, amount);
    }

    function claim() external settle(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "LockedStaking: nothing to claim");
        require(rewardToken.transfer(msg.sender, reward), "LockedStaking: transfer failed");
        rewards[msg.sender] = 0;
        emit RewardPaid(msg.sender, reward);
    }

    /// @notice Starts a reward period. The reward must already be held by this contract.
    function notifyRewardAmount(uint256 reward) external {
        require(msg.sender == owner, "LockedStaking: not owner");
        _startPeriod(reward, rewardToken.balanceOf(address(this)));
        emit RewardAdded(reward, periodFinish);
    }
}
