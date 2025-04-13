// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IERC20Minimal {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
}