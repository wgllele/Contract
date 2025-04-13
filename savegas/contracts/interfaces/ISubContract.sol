// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface ISubContract{
    function sendErc20s(bytes memory transactions) external;
    function sendEth(uint v) external;
    event TransferEthTo(address indexed to, uint256 indexed timestamp, uint256 value);
}