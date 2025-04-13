// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./IMultiSigOperator.sol";
struct MerchantLite {
    /// Fee payment ratio for each merchant
    uint256 feeRate;
    /// Agency rate
    uint256 agentRate;
    /// Cold contract storage pool address
    address payable coldPool;
    /// Agent’s multi-signature address
    address multiSigAgentAddr;
    /// Claim address
    address emergencyAddr;
}

interface IMultiSigColdLite{
    function initManagers(MerchantLite calldata data,IMultiSigOperator _multiSigOperator) external;
    function initOwner() external;
    event TransferCommissionLogs(address indexed token, uint256 indexed totalCommission,uint256 indexed agentCommission,uint256 operatorCommission,uint256 transBalHot);
}