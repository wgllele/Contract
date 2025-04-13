// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IMultiSigAgent{
    function initManagers(uint ratio,uint expirationTime,address _agentFeeAddr,address[] memory _managers) external;
    function getAgentFeeAddr() external view returns(address);
}
