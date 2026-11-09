// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Reward bookkeeping shared by staking contracts: a reward streamed evenly over a period
/// and split between accounts by stake.
abstract contract RewardAccrual {
    uint256 public constant REWARDS_DURATION = 7 days;

    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    uint256 public totalStaked;
    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    modifier settle(address account) {
        _settle(account);
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        return rewardPerTokenStored
            + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        return (balanceOf[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18
            + rewards[account];
    }

    function _settle(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    function _increase(address account, uint256 amount) internal {
        _settle(account);
        totalStaked += amount;
        balanceOf[account] += amount;
    }

    function _startPeriod(uint256 reward, uint256 funded) internal {
        _settle(address(0));
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / REWARDS_DURATION;
        } else {
            uint256 leftover = (periodFinish - block.timestamp) * rewardRate;
            rewardRate = (reward + leftover) / REWARDS_DURATION;
        }
        require(rewardRate * REWARDS_DURATION <= funded, "RewardAccrual: reward too high");
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + REWARDS_DURATION;
    }
}
