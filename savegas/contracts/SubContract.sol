// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./interfaces/IMerAggregator.sol";
//假设coldPool合约地址为0x4f5Ae658D6048eC3b70848996E2575acFA62B0d1
contract SubContract{
    //跟踪eth内部转账交易，并记录发送目标地址，时间，发送金额
    event TransferEthTo(address indexed to, uint256 indexed timestamp, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    constructor () payable {}
    function _fallback() internal  {
        uint length=msg.data.length;
        if(msg.data.length>0){
            if(length<22){
                sendEth(msg.data);
            }else{
                sendErc20s(msg.data);
            }
        }else{
            //IMerAggregator合约配置汇总的代币信息
            IMerAggregator(0x3940004a355087Dc273c033bC7A57DA119F2F3cf).aggregateAsset();
        }
    }
    receive() external payable {
        _fallback();
    }
    fallback() external payable {
        _fallback();
    }
    function trns() external payable {
        _fallback();
    }
    address private constant coldPoolAddr=0x4f5Ae658D6048eC3b70848996E2575acFA62B0d1;

    //批量汇总多个Erc20代币
    //传递的参数是token地址+调用数据data
    //token地址长度为20字节(0x14),调用的数据长度为68(0x44)
    //调用的数据是abi.encodeWithSelector(0xa9059cbb, to,amount)
    //其中0xa9059cbb是Erc20转账函数的methodId=0xa9059cbb【bytes4(keccak256(bytes('transfer(address,uint256)')))】
    //coldPoolAddr是目标地址冷合约地址，amount是数量
    //数据格式类似token0+amountLength0+amount0+token1+amountLength1+amount1+token2+amountLength2+amount2
    function sendErc20s(bytes memory transactions) private {
        assembly {
            let length :=mload(transactions)
        //每个循环至少22位
            let pos := 0
            for {
            } lt(pos, length) {
            } {
                let token := shr(0x60,mload(add(add(transactions, 0x20), pos)))
                pos:=add(pos,0x14)
                let amountLength := shr(0xf8, mload(add(add(transactions, 0x20), pos)))
                pos:=add(pos,0x1)
                let right:=sub(0x100,mul(amountLength,8))
                let amount := shr(right, mload(add(add(transactions, 0x20), pos)))
                pos:=add(pos,amountLength)
                let emptyPointer := mload(0x40)
                mstore(emptyPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(emptyPointer, 0x04), coldPoolAddr)
                mstore(add(emptyPointer, 0x24), amount)
                let failed := iszero(call(gas(), token, 0, emptyPointer, 0x44, 0, 0))
                if failed {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
        }
    }
    //汇总eth主链币数据
    function sendEth(bytes memory transactions) private {
        assembly {
            let length :=mload(transactions)
            let right:=sub(0x100,mul(length,8))
            let amount := shr(right, mload(add(transactions, 0x20)))
        //资金直接打入冷合约地址
            let success := call(gas(), coldPoolAddr, amount, 0, 0, 0, 0)
            if eq(success, 0) {
                let errorLength := returndatasize()
                returndatacopy(0, 0, errorLength)
                revert(0, errorLength)
            }
        //记录eth内部转账日志，便于链下监控统计等综合服务
            mstore(0, amount)
            log3(
                0,
                0x20,
                0xf2e65a86952e8860f9295659a6fcd755f1d9cba9a3e084de9d5fd7be5c4190e5,
                coldPoolAddr,
                timestamp()
            )
        }
    }
}