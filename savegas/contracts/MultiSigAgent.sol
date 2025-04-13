// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;
import "./MultiSig.sol";
contract MultiSigAgent is MultiSig {
    constructor() {
    }
    //代理分佣费用地址
    address public agentFeeAddr;
    function getAgentFeeAddr() external view returns(address){
        return agentFeeAddr;
    }
    //最近平衡资金时间
    uint public lastBalancedTime;
    //初始化管理员，多签比例，签名超时时间，代理分佣地址
    //ratio:多签比例,比如70代表70%，expirationTime是多签超时时间，秒为单位，
    //_primAgentFeeAddr是代理分佣地址，_managers是多签管理员，有序的，顺序为地址从小到大排序
    function initManagers(uint ratio,uint expirationTime,address _agentFeeAddr,address[] calldata _managers) external{
        require(status!=1,"only init once");
        require(ratio >= 60 && ratio <= 100);
        status=1;
        agentFeeAddr = _agentFeeAddr;
        uint length=_managers.length;
        require(length>=3,"Manager cannot be less than htree");
        for (uint i=1;i<length;++i) {
            //保证有序性
            require(_managers[i] > _managers[i-1]);
        }
        managerInfo=ManagerInfo(getManagerNumber(length,ratio,1e2),expirationTime,_managers);
        _ratio=ratio;
    }
    //设置代理分佣地址，_primAgentFeeAddr是代理分佣地址，signatures是多签数据
    function setAgentFeeAddr(address _agentFeeAddr,bytes memory signatures) external nonReentrant{
       //获取管理员信息
        ManagerInfo memory _managerInfo=managerInfo;
        //获取需要多签的签名数量
        uint managerNumber= _managerInfo.managerNumber;
        //获取签名有效期限(截止时间，单位为妙)
        uint expirationTime= block.timestamp-_managerInfo.expirationTime;
        //获多签管理员名单列表
        address[] memory managers=_managerInfo.managers;
        //最近签名过的管理员地址，用于排重用途
        address lastOwner = address(0);
        //当前签名的管理员地址，用于验签用途
        address currentOwner;
        uint t;//签名的时间戳(秒为单位)
        uint8 j;//签名管理员在合约管理员信息的名单列表里面的位置(下标)
        uint8 v;//签名数据V
        bytes32 r;//签名数据R
        bytes32 s;//签名数据S
        //签名的原始数据datahash，满足EIP712并包括合约nonce等信息
        bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.setAgentFeeAddr.selector,_agentFeeAddr,new bytes(0)));
        for (uint i;i<managerNumber;++i) {
            (t,j,v, r, s) = signatureSplit(signatures, i);
            require(t >expirationTime);//验证是否过期
            //获取签名的明文数据来恢复地址信息，其中明文数据是数据datahash和签名时间再次hash完成
            currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
            require(currentOwner > lastOwner);//保证账户不会重复
            require(currentOwner==managers[j]);
            lastOwner = currentOwner;
        }
        agentFeeAddr=_agentFeeAddr;
    }
}