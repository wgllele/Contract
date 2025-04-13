// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;
import "./interfaces/IAsset.sol";
import "./lib/ReentrancyGuardTransient.sol";
//资产合约，被冷合约和热合约继承的公用方法
contract Asset is IAsset, ReentrancyGuardTransient{
    address private _owner;
    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);
    constructor() payable{}
    receive() external payable {}
    fallback() external payable {}
    //为了首次初始化操作使用，如果等于10代表已经初始化过
    uint public status;
    //初始化合约的管理员，这个管理员指定的是多签合约地址
    function initOwner(address initialOwner) external{
        require(status!=10,"only init once");
        status=10;
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _owner = initialOwner;
    }
    modifier onlyOwner() {
        if (owner() !=msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        _;
    }
    function owner() public view returns (address) {
        return _owner;
    }
    //批量汇总多个Erc20代币
    //传递的参数是token地址+调用数据data
    //token地址长度为20字节(0x14),调用的数据长度为68(0x44)
    //调用的数据是abi.encodeWithSelector(0xa9059cbb, to,amount)
    //其中0xa9059cbb是Erc20转账函数的methodId=0xa9059cbb【bytes4(keccak256(bytes('transfer(address,uint256)')))】
    //to是目标地址冷合约地址，amount是数量
    //数据格式类似token0+data0+token1+data1+token2+data2
    function sendErc20(bytes memory transactions) external onlyOwner nonReentrant {
        assembly {
            //获取transactions总长度，用于下面循环判断
            let length := mload(transactions)
            //每次获取32字节(加载256位)
            let i := 0x20
            for {
            } lt(i, length) {
            } {
                //地址类型是20字节的，但是获取的数据是32字节的，后面12字节数据不是想要的，所以右移12字节(96位)
                let to := shr(0x60, mload(add(transactions, i)))
                //刨去token地址部分，获取32字节数据(256位)
                //数据的长度是68(0x44)，其中methodId占用4，第一个参数占用32，第二个参数占用32
                let data := add(transactions, add(i, 0x14))
                let success := call(gas(), to, 0, data, 0x44, 0, 0)
                if eq(success, 0) {
                    let errorLength := returndatasize()
                    returndatacopy(0, 0, errorLength)
                    revert(0, errorLength)
                }
                //token地址是20(0x14),参数长度为68(0X44),其中0x58=0x14+0x44
                //由于每次获取数据0x58，所以循环累加0x58
                i := add(i, 0x58)
            }
        }
    }

    function sendEths(bytes memory transactions) external onlyOwner  payable nonReentrant{
        assembly {
            //获取transactions总长度，用于下面循环判断
            let length := mload(transactions)
            //每次获取32字节(加载256位)
            let i := 0x20
            for {
            } lt(i, length) {
            } {
                //地址类型是20字节的，但是获取的数据是32字节的，后面12字节数据不是想要的，所以右移12字节(96位)
                let to := shr(0x60, mload(add(transactions, i)))
                //转账金额类型是20字节的，所以直接获取的数据是32字节，不需要任何处理
                let _amount := mload(add(transactions, add(i, 0x14)))
                let success := call(gas(), to, _amount, 0, 0, 0, 0)
                if eq(success, 0) {
                    let errorLength := returndatasize()
                    returndatacopy(0, 0, errorLength)
                    revert(0, errorLength)
                }
                //记录eth内部转账日志，便于链下监控统计等综合服务
                mstore(0, _amount)
                log3(
                        0,
                        0x20,
                        0xf2e65a86952e8860f9295659a6fcd755f1d9cba9a3e084de9d5fd7be5c4190e5,
                        to,
                        timestamp()
                    )
                //token地址是20(0x14),转账金额长度为32(0X20),其中0x34=0x14+0x20
                //由于每次获取数据0x34，所以循环累加0x34
                i := add(i, 0x34)
            }
        }
    }
}