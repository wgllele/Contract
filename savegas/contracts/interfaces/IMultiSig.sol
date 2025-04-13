// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

struct Commission {
    uint256 totalCommission;
    uint256 agentCommission;
    uint256 operatorCommission;
    uint256 transBalHot;
    uint256 paytocolCommission;
}

interface IMultiSig {
    function getManagerInfo() external view returns(uint managerNumber,uint expirationTime,address[] memory managers);
    function getTransactionHash(bytes memory transactions) external view returns (bytes32 txHash);
}