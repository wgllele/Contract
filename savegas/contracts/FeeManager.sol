// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {SafeMath} from "./lib/SafeMath.sol";
import {StakingManager} from "./StakingManager.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FeeManager is Ownable(msg.sender){
    using SafeMath for uint256;
    using SafeERC20 for StakingManager;
    StakingManager public rewardToken;

    constructor(
        StakingManager _rewardToken
    )  {
        require(address(_rewardToken) != address(0), "rewardToken address not set!");
        rewardToken = _rewardToken;
    }
    uint256 public rewardPerFee=1e3;
    uint256 public baseFee=1e12;
    mapping(uint256 index => uint256 fee) public  fees;
    uint256[] public ranges;
    function rmRange(uint256 _index)onlyOwner external returns(bool) {
        uint256[] memory _ranges=ranges;
        uint length=_ranges.length-1;
        require(_index<=length, "not exist");
        //从需要删除的管理员数组列表中的位置开始遍列，前一位重新赋值为后一位的数据直到数组末尾
        for (uint i=_index; i<length; ++i) {
            _ranges[i]=_ranges[i+1];
            fees[i]=fees[i+1];
        }
        ranges=_ranges;
        ranges.pop();
        return true;
    }
    function updateFee(uint256 fee,uint256 _index) onlyOwner external returns(bool) {
        fees[_index]=fee;
        return true;
    }
    function updateRange(uint256 range,uint256 _index) onlyOwner external returns(bool) {
        require(_index<ranges.length, "not exist");
        ranges[_index]=range;
        return true;
    }
    function updateRangeAndFee(uint256 range,uint256 _index,uint fee) onlyOwner external returns(bool) {
        require(_index<ranges.length, "not exist");
        ranges[_index]=range;
        fees[_index]=fee;
        return true;
    }
    function initConfig(uint256[] memory _ranges,uint256[] memory _fees)onlyOwner external returns(bool){
        ranges=_ranges;
        require(_fees.length==_ranges.length, "error");
        for (uint i; i<_ranges.length; ++i) {
            fees[i]=fees[i+1];
        }
        return true;
    }
    function addRangeAndFee(uint256 range,uint256 _index,uint fee) onlyOwner external returns(bool) {
        uint256[] memory _ranges=ranges;
        uint length=_ranges.length;
        //验证新添加地址的位置，保证顺序性
        if(_index==0){
            require(range<_ranges[0]);
        }else if(_index<length){
            require(
                range<_ranges[_index]&&
                range>_ranges[_index-1]
            );
        }else{
            require(_index==length&&range>_ranges[_index-1]);
        }
        ranges.push();
        //重新赋值给临时内存变量managers，便于后面使用从而节省gas费用
        _ranges=ranges;
        //从数组末尾向前遍列，后一位重新赋值为前一位数据直到需要插入数据的位置
        for(uint i=length;i>_index;--i){
            _ranges[i]=_ranges[i-1];
        }
        //插入数据位置替换为新添加的管理员
        _ranges[_index]=range;
        fees[_index]=fee;
        ranges=_ranges;
        return true;
    }
    function setRewardPerFee(
        uint _rewardPerFee
    ) onlyOwner external returns(bool) {
        rewardPerFee=_rewardPerFee;
        return true;
    }
    function setBaseFeeAndRewardPerFee(
        uint _baseFee,
        uint _rewardPerFee
    ) onlyOwner external returns(bool) {
        baseFee=_baseFee;
        rewardPerFee=_rewardPerFee;
        return true;
    }
    function setBaseFee(
        uint _baseFee
    ) onlyOwner external returns(bool) {
        baseFee=_baseFee;
        return true;
    }

    function getFeeRate(
        address operator
    )  external returns(uint feeRate) {
        feeRate=baseFee;
        uint bal=rewardToken.balanceOf(operator);
        uint total=rewardToken.totalSupply();
        feeRate=feeRate.sub(bal*10000/total);
        rewardToken.burnFrom(operator,bal);
    }

    function getRangeFeeRate(
        address account
    )  external view returns(uint) {
        uint256[] memory _ranges=ranges;
        uint length=_ranges.length;
        uint bal=rewardToken.balanceOf(account);
        for(uint i;i<length;++i){
            if(bal<=ranges[i]){
                return fees[i];
            }
        }
        return 0;
    }
}