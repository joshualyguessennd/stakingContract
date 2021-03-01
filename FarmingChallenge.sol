//"SPDX-License-Identifier: UNLICENSED"
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "./RewardToken.sol";

contract FarmingChallenge is Ownable{
    
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    struct StakerInfo{
        uint256 amount; // Track How many Lp Token user has provide
        uint256 rewardDebt; //  Rewards from the staker according to certain calculation conditions
    }
    
    
    
    //track created pool 
    struct PoolInfo {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 totalPoolAccumalate;
        uint256 lastRewardBlock;
    }
    
    
    RewardToken public rewardToken; //importing the RewardToken into this contract
    
    
    PoolInfo[] public poolInfo; // array to store all pool
    
    
    // a mapping to get the info of each staker
    mapping (uint256 => mapping(address => StakerInfo)) public stakerInfo;
    
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    
    // the block number where the mining activity starts
    uint256 public startBlock;
    
    
    // rewardToken minted per block.
    uint256 public rewardPerBlock;
    
    
    
    
    //Declared Event, pid = pool id
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    
    // event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount); for people who want to Withdraw urgently fund without claiming reward 
    
    
    //setting up the contract constructor
    
    constructor(
        RewardToken _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock
        ) public {
        rewardToken = _rewardToken;
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
    }
    
    //get the number of existing pool in the contract 
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }
    
    //function to create Pool of allowed token
    function addAllowLpToken(IERC20 _lpToken, uint256 _allocPoint) public onlyOwner {
        
        uint256 latestRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        
        
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            totalPoolAccumalate: 0,
            allocPoint: _allocPoint,
            lastRewardBlock: latestRewardBlock
        }));
    }
    
    
    
    
    //each time a staker make deposit we need to update the reward for this pool
    
    function updatePool(uint256 _pid) public  {
        PoolInfo storage pool = poolInfo[_pid];
        if(block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 tokenSupply = pool.lpToken.balanceOf(address(this));
        if(tokenSupply == 0) {
            pool.lastRewardBlock == block.number;
            return;
        }
        uint256 reward = rewardPerBlock.mul(pool.allocPoint).div(totalAllocPoint);
        rewardToken.mint(address(this), reward);
        pool.totalPoolAccumalate = pool.totalPoolAccumalate.add(reward.mul(1e12).div(tokenSupply));
        pool.lastRewardBlock = block.number;
        
    }
    
    
    // get the reward each staker will get for staking
    function pendingReward(uint256 _pid, address _staker) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        StakerInfo storage staker = stakerInfo[_pid][_staker];
        uint256 totalPoolAccumalate = pool.totalPoolAccumalate;
        uint256 tokenSupply = pool.lpToken.balanceOf(address(this));
        if(block.number > pool.lastRewardBlock && tokenSupply != 0) {
            uint256 reward = rewardPerBlock.mul(pool.allocPoint).div(totalAllocPoint);
            totalPoolAccumalate = totalPoolAccumalate.add(reward.mul(1e12).div(tokenSupply));
        }
        return staker.amount.mul(totalPoolAccumalate).div(1e12).sub(staker.rewardDebt);
    }
    
    // function that allowed user to stake their lpToken
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        StakerInfo storage staker = stakerInfo[_pid][msg.sender];
        
        if(staker.amount > 0) {
            uint256 pendingRWT = staker.amount.mul(pool.totalPoolAccumalate).div(1e12).sub(staker.rewardDebt);
            if(pendingRWT > 0) {
                rewardTransfer(msg.sender, pendingRWT);
            }
        }
        
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            staker.amount = staker.amount.add(_amount);
        }
        
        emit Deposit(msg.sender, _pid, _amount);
    }
    
    //function to withdraw lpToken stake inside pools
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        StakerInfo storage staker = stakerInfo[_pid][msg.sender];
        require(staker.amount >= _amount, "you can't withdraw what you don't have");
        updatePool(_pid);
        uint256 pendingRWT = staker.amount.mul(pool.totalPoolAccumalate).div(1e12).sub(staker.rewardDebt);
        if(pendingRWT > 0) {
           rewardTransfer(msg.sender, pendingRWT); 
        }
        if(_amount > 0) {
            staker.amount = staker.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        staker.rewardDebt = staker.amount.mul(pool.totalPoolAccumalate).div(1e12);
        emit Withdraw(msg.sender,_pid, _amount);
    }
    
    
    //function emergencyWithdraw(uint256 _pid) public {
    //    PoolInfo storage pool = poolInfo[_pid];
    //    StakerInfo storage staker = stakerInfo[_pid][msg.sender];
    //    pool.lpToken.safeTransfer(address(msg.sender), staker.amount);
    //    emit EmergencyWithdraw(msg.sender, _pid, staker.amount);
    //    staker.amount = 0;
    //    staker.rewardDebt = 0;
    //}
    
    //function to check if transfer request is not high than reward balance
    function rewardTransfer(address _to, uint256 _amount) internal {
        uint256 rewardBalance = rewardToken.balanceOf(address(this));
        if(_amount > rewardBalance) {
            rewardToken.transfer(_to, rewardBalance);
        } else {
            rewardToken.transfer(_to, _amount);
        }
    }
}
