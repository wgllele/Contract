// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IMultiSigProtocol{
    function baseFeeRate() external view returns(uint256);
    function getFeeRate(address mulOperatorAddr) external view returns (address _feeCollector, uint256 _feeRate);
}