// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IMultiSigOperator{
    function initManagers(uint ratio,uint _expirationTime,address _operatorFeeAddr,address _mltiSigProtocol, address[] calldata _managers) external;
    function getManagerInfo()external view returns(uint managerNumber,uint expirationTime,address[] calldata managers);
    function getOperatorFeeAddr() external view returns(address);
    function mltiSigProtocol() external view returns(address);
}
