// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {SafeMath} from "./lib/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
contract StakingManager is Ownable(msg.sender), ERC20, ERC20Permit{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    //address constant burnAddress = 0x0000000000000000000000000000000000000001;
    struct UserInfo
    {
        uint256 amount;                 // How many tokens the user has provided.
        uint256 rewardDebt;                 // Reward debt. See explanation below.
    }

    struct PoolInfo
    {
        uint256 lastRewardBlock;            // Last block number that reward distribution occured.
        uint256 accRewardPerShare;          // Accumulated reward per share, times 1e12. See below.
    }

    IERC20 public immutable stakingToken;
    uint256 public rewardPerBlock;                    // Reward tokens created per block.
    uint256 public immutable startBlock;              // The block number at which reward distribution starts.
    uint256 public immutable endBlock;                // The block number at which reward distribution ends.
    uint256 public immutable lockBlock;               // The block number at which deposit period ends.
    PoolInfo public poolInfo;

    mapping (address => UserInfo) public userInfo;     // Info of each user that stakes tokens.

    event Withdraw(address indexed user, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event Burn(uint256 amount);

    constructor(
        IERC20 _stakingToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _lockBlock
    ) ERC20("RewardToken", "Reward Token") ERC20Permit("Reward Token") {
        require(address(_stakingToken) != address(0), "stakingToken address not set!");
        require(_rewardPerBlock != 0, "_rewardPerBlock not set!");
        require(_startBlock < _lockBlock, "_startBlock too high!");
        require(_lockBlock < _endBlock, "_lockBlock too high!");

        stakingToken = _stakingToken;
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        endBlock = _endBlock;
        lockBlock = _lockBlock;
        poolInfo = PoolInfo({
            lastRewardBlock: _startBlock,
            accRewardPerShare: 0
        });
    }
    address public totalPoolAddr;
    function setTotalPoolAddr(
        address _totalPoolAddr
    ) onlyOwner public returns(bool) {
        totalPoolAddr=_totalPoolAddr;
        return true;
    }
    /**
     * @dev Return reward multiplier over the given _from to _to blocks based on block count.
     * @param _from First block.
     * @param _to Last block.
     * @return Number of blocks.
     */
    function getMultiplier(uint256 _from, uint256 _to) internal view returns (uint256) {
        if (_to < endBlock) {
            return _to.sub(_from);
        } else if (_from >= endBlock) {
            return 0;
        } else {
            return endBlock.sub(_from);
        }
    }

    /**
     * @dev View function to see pending rewards on frontend.
     * @param _user Address of a specific user.
     * @return Pending rewards.
     */
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 accRewardPerShare = poolInfo.accRewardPerShare;
        uint256 stakingSupply = stakingToken.balanceOf(address(this));
        if (block.number > poolInfo.lastRewardBlock && stakingSupply != 0) {
            uint256 multiplier = getMultiplier(poolInfo.lastRewardBlock, block.number);
            uint256 tokenReward = multiplier.mul(rewardPerBlock);
            accRewardPerShare = accRewardPerShare.add(tokenReward.mul(1e12).div(stakingSupply));
        }
        return user.amount.mul(accRewardPerShare).div(1e12).sub(user.rewardDebt);
    }
    function setTokenPerBlock(uint256 _newPerBlock) public onlyOwner {
        updatePool();
        rewardPerBlock = _newPerBlock;
    }
    /**
     * @dev Update reward variables of the given pool to be up-to-date.
     */
    function updatePool() public {
        if (block.number <= poolInfo.lastRewardBlock) {
            return;
        }
        uint256 stakingSupply = stakingToken.balanceOf(address(this));
        if (stakingSupply == 0) {
            poolInfo.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(poolInfo.lastRewardBlock, block.number);
        uint256 tokenReward = multiplier.mul(rewardPerBlock);
        poolInfo.accRewardPerShare = poolInfo.accRewardPerShare.add(tokenReward.mul(1e12).div(stakingSupply));
        poolInfo.lastRewardBlock = block.number;
    }

    /**
     * @dev Deposit staking tokens to the Extinction Pool for rewards allocation and/or withdraw outstanding rewards.
     * @param _amount Amount of staking tokens to deposit.
     */
    function transact(uint256 _amount,address rewardAddr,bool redeem) public {
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        if (user.amount > 0) {
            uint256 tempRewardDebt = user.amount.mul(poolInfo.accRewardPerShare).div(1e12);
            uint256 pending = tempRewardDebt.sub(user.rewardDebt);
            user.rewardDebt = tempRewardDebt;//Avoid reentrancy
            _mint(rewardAddr, pending);
            emit Withdraw(msg.sender, pending);
        }
        if (block.number < lockBlock && _amount != 0) {
            stakingToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
            user.rewardDebt = user.amount.mul(poolInfo.accRewardPerShare).div(1e12);
            emit Deposit(msg.sender, _amount);
        }
        if (block.number >= endBlock&&redeem) {
            stakingToken.safeTransfer(msg.sender, user.amount);
            user.amount = 0;
            user.rewardDebt = user.amount.mul(poolInfo.accRewardPerShare).div(1e12);
            emit Burn(user.amount);
        }
        user.rewardDebt = user.amount.mul(poolInfo.accRewardPerShare).div(1e12);
    }
    /**
     * @dev Destroys a `value` amount of tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 value) external  {
        _burn(_msgSender(), value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, deducting from
     * the caller's allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `value`.
     */
    function burnFrom(address account, uint256 value) external {
        _spendAllowance(account, _msgSender(), value);
        _burn(account, value);
    }
}