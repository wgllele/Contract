// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

contract TransactionTool{
    function getPackedTransactions(
        bytes[] memory transactionDatas
    ) external pure returns (bytes memory transactions){
        uint length= transactionDatas.length;
        for(uint i;i<length;++i){
            transactions=abi.encodePacked(transactions,transactionDatas[i]);
        }
    }
    function getErc20TransferTransactions(
        address  token,
        address to,
        uint amount
    ) external pure returns (bytes memory transactions){
        bytes memory data=abi.encodeWithSelector(0xa9059cbb, to,amount);
        transactions=abi.encodePacked(
            token,
            uint256(0),
            data.length,
            data
        );
    }
    function getErc20TransferFromTransactions(
        address  token,
        address from,
        address to,
        uint amount
    ) external pure returns (bytes memory transactions){
        bytes memory data=abi.encodeWithSelector(0x23b872dd,from,to,amount);
        transactions=abi.encodePacked(
            token,
            uint256(0),
            data.length,
            data
        );
    }
    function getEthTransferTransactions(
        address to,
        uint amount
    ) external pure returns (bytes memory transactions){
        transactions=abi.encodePacked(
            to,
            amount,
            uint256(0)
        );
    }
}