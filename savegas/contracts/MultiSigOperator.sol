// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;
import "./MultiSig.sol";
contract MultiSigOperator is MultiSig {
    constructor() {
    }
    address public operatorFeeAddr;
    //总合约地址
    address public mltiSigProtocol;
    //初始化配置信息，ratio为多签比例，_expirationTime为多签有效期限，_utcFeeAddr为utc费用地址，
    //_managers为排好序的管理员地址列表,地址顺序由小到大
    function initManagers(uint ratio,uint _expirationTime,address _operatorFeeAddr,address _mltiSigProtocol,address[] calldata _managers) external{
        require(status!=1,"only init once");
        require(ratio >= 60 && ratio <= 100);
        status=1;
        uint length=_managers.length;
        require(length>=3,"Manager cannot be less than three");
        for (uint i=1;i<length;++i) {
            require(_managers[i] > _managers[i-1]);
        }
        managerInfo=ManagerInfo(getManagerNumber(length,ratio,1e2),_expirationTime,_managers);
        operatorFeeAddr=_operatorFeeAddr;
        _ratio=ratio;
        mltiSigProtocol = _mltiSigProtocol;
    }
    
    function getOperatorFeeAddr() external view returns(address){
        return operatorFeeAddr;
    }
    //设置_utcFeeAddr
    function setOperatorFeeAddr(address _operatorFeeAddr,bytes memory signatures) external nonReentrant{
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
        bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.setOperatorFeeAddr.selector, _operatorFeeAddr,new bytes(0)));
        for (uint i;i<managerNumber;++i) {
             (t,j,v, r, s) = signatureSplit(signatures, i);
            require(t >expirationTime);//验证是否过期
            //获取签名的明文数据来恢复地址信息，其中明文数据是数据datahash和签名时间再次hash完成
            currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
            require(currentOwner > lastOwner);//保证账户不会重复
            require(currentOwner==managers[j]);
            lastOwner = currentOwner;
        }
        operatorFeeAddr=_operatorFeeAddr;
    }
}