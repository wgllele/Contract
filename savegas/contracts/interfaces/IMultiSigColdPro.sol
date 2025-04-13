// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./IMultiSigOperator.sol";
struct Merchant {
    /// Fee payment ratio for each merchant
    uint256 feeRate;
    /// Each merchant rebalance funds limit time
    uint256 rebalanceTime;
    /// Agency rate
    uint256 agentRate;
    /// Hot contract storage pool address
    address payable hotPool;
    /// Cold contract storage pool address
    address payable coldPool;
    /// Agent’s multi-signature address
    address multiSigAgentAddr;
}

interface IMultiSigColdPro{
    function initManagers(Merchant memory data,IMultiSigOperator _multiSigOperator,uint ratio,uint expirationTime,address[] memory _managers) external;
    function initOwner() external;
    event TransferCommissionLogs(address indexed token, uint256 indexed totalCommission,uint256 indexed agentCommission,uint256 operatorCommission,uint256 transBalHot);
}