//"SPDX-License-Identifier: UNLICENSED"
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";
import "./RewardToken.sol";





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
    
    RewardToken rewardToken; // reward token 
    
    
    //events
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    
    constructor (
        RewardToken _rewardToken
    ) public {
        rewardToken = _rewardToken;
    }
    

    // get the total existing pools 
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }
    


    // function to create a new pool
    function createPool(IERC20 _lpToken, uint256 _period) public onlyOwner {
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            totalPointAccumulated: 0,
            lockPeriod: _period.mul(lockUnit),
            startBlock: block.timestamp
        }));
    }


    
    
    //function to get the userPoint
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
    
    // stake your lpToken
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
    
    
    // withdraw your lpToken
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
    
    
}