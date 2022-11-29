//SPDX-License-Identifier:MIT
pragma solidity ^0.8.17;

import "./IERC20.sol";
contract StakingRewards {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    address public owner;
    //Variable needed to keep trck of the rewards
    uint public duration;
    uint public finishedAt;
    uint public updatedAt;
    uint public rewardRate;
    uint public rewardPerTokenStored;

    mapping(address => uint) public userRewardPerTokenPaid;
    mapping(address => uint) public rewards;

    //Define variables needed to keep track of the total supply of staking token 
    //and amount staked per user
    uint public totalSupply;
    mapping(address => uint) public balanceOf;

      modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized!!!");
        _;
    }

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if(_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        _;
    }

    constructor (address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        owner = msg.sender;
    }

    function setRewardsDuration(uint _duration) external onlyOwner {
        require(finishedAt < block.timestamp, "Staking Ungoing");
        duration = _duration;
    }
    function notifyRewardAmount(uint _amount) external updateReward(address(0)) {
        if (block.timestamp > finishedAt) {
            rewardRate = _amount/duration;
        } else {
            rewardRate = (_amount + ((finishedAt - block.timestamp) * rewardRate))/duration;
        }
        
        require(rewardRate > 0, "Reward must be greater than zero");
        require(rewardRate * duration <= rewardToken.balanceOf(address(this)), "Total Reward is greater than Token balance");

        finishedAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }
    function stake(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "Please stake higher");
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
    }
    function withdraw(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0 && _amount <= balanceOf[msg.sender], "Withdraw a valid amount");
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    function lastTimeRewardApplicable() public view returns(uint) {
        return _min(block.timestamp, finishedAt);
    }
    function rewardPerToken() public view returns(uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        } else{
            return rewardPerTokenStored + (rewardRate *
             (lastTimeRewardApplicable() - updatedAt) * 1e18) / totalSupply;
        }
    }
    function earned(address _account) public view returns(uint) {
        return (balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18 + rewards[_account];
    }
    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.transfer(msg.sender, reward);
        }
    }

    function _min(uint x, uint y) private pure returns(uint) {
        return x <= y ? x : y;
    }

}