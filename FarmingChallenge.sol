//"SPDX-License-Identifier: UNLICENSED"
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";
import "./RewardToken.sol";


//to do , create a function that allow withdraw only for multiple of 1 days .


contract FarmingTimeBaseReward is Ownable, ChainlinkClient {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    
    uint256 public lockUnit = 1 days;
    


    //Pool information
    struct PoolInfo{
        IERC20 lpToken;
        uint256 totalPointAccumulated;
        uint256 lockPeriod;
        uint256 startBlock;
        
    }
    
    // staker information
    struct StakerInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 point;
        uint256 dailyPoint;
    }
    
    PoolInfo[] public poolInfo; //array to store all pool 
    StakerInfo[] public user;

    mapping(uint256 => mapping(address => StakerInfo)) stakerInfo; // mapping to store staker information
    
    uint256 public startBlock; // block where the user actitvity start;
    
    RewardToken rewardToken;
    
    
    //events
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    
    constructor (
        RewardToken _rewardToken
    ) public {
        rewardToken = _rewardToken;
    }
    
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }
    


    
    function createPool(IERC20 _lpToken, uint256 _period) public onlyOwner {
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            totalPointAccumulated: 0,
            lockPeriod: _period.mul(lockUnit),
            startBlock: block.timestamp
        }));
    }


    
    
    
    function getUserPoint(uint256 _pid, address _staker) public view returns (uint256){
        StakerInfo storage staker = stakerInfo[_pid][_staker];
        return staker.point;
    }
    
    // mint the reward
    function generateReward(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if(block.timestamp >= pool.startBlock.mul(pool.lockPeriod)){
            uint256 reward = pool.totalPointAccumulated;
            rewardToken.mint(address(this), reward);
        } else {
            return;
        }
    }


      
    
    // claim the reward token
    function claim(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        StakerInfo storage staker = stakerInfo[_pid][msg.sender];
        uint256 balanceLp = pool.lpToken.balanceOf(address(this));
        if(block.timestamp >= pool.startBlock.mul(pool.lockPeriod)){
            staker.rewardDebt = staker.point.mul(balanceLp).div(pool.totalPointAccumulated);
            rewardToken.transfer(msg.sender, staker.rewardDebt);
            staker.rewardDebt = 0;
        }
        
    }
    
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        StakerInfo storage staker = stakerInfo[_pid][msg.sender];
        if(staker.amount > 0){
            staker.point = staker.amount.add(_amount);
        }
        if(_amount > 0){
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            staker.amount = staker.amount.add(_amount);
            pool.totalPointAccumulated = pool.totalPointAccumulated.add(_amount);
        }
        
        emit Deposit(msg.sender, _pid, _amount);
    }
    
    
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        StakerInfo storage staker = stakerInfo[_pid][msg.sender];
        require(staker.amount >= _amount, "error withdraw");
        
        
        if(_amount > 0) {
            pool.lpToken.safeTransfer(msg.sender, _amount);
            staker.amount = staker.amount.sub(_amount);
            pool.totalPointAccumulated = pool.totalPointAccumulated.sub(_amount);
        }
        emit Withdraw(msg.sender, _pid, _amount);
    }
    
    
    function safeRewardTransfer(address _to, uint256 _amount) internal {
        uint256 rewardBal = rewardToken.balanceOf(address(this));
        if(_amount > rewardBal){
            rewardToken.transfer(_to, _amount);
        } else {
            rewardToken.transfer(_to, rewardBal);
        }
    }
    
}