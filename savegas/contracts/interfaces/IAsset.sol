// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IAsset{
    function sendErc20(bytes memory transactions) external;
    function sendEths(bytes memory transactions) external payable;
    function initOwner(address initialOwner) external;
    event TransferEthTo(address indexed to, uint256 indexed timestamp, uint256 value);
}