// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IFeeRateProvider {
    function getFeeRate(address operator) external view returns (uint256);
}