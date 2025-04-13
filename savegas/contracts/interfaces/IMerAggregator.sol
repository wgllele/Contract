// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IMerAggregator{
    function aggregateAsset() external payable;
    function initConfig(address[] memory _tokens,address payable _coldPool,address _multiSigCold) external;
    function setTokens(address[] memory _tokens) external;
    event PaymentReceived(address indexed sender, address indexed token, uint256 indexed amount, uint256 orderId);
}