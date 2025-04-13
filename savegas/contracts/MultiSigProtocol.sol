// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;
import "./MultiSig.sol";
import "./interfaces/IFeeRateProvider.sol";

contract MultiSigProtocol is MultiSig {
    constructor() {
    }
    //手续费默认比例
    uint256 public baseFeeRate;
    //手续费接收地址
    address public feeCollector;
    //手续费比例合约
    address public feeRateProvider;
    //手续费开关
    bool public feeEnabled;
    //初始化配置信息，ratio为多签比例，_expirationTime为多签有效期限，
    //_managers为排好序的管理员地址列表,地址顺序由小到大
    function initManagers(uint ratio,uint _expirationTime,address[] calldata _managers) external{
        require(status!=1,"only init once");
        require(ratio >= 60 && ratio <= 100);
        status=1;
        uint length=_managers.length;
        require(length>=3,"Manager cannot be less than three");
        for (uint i=1;i<length;++i) {
            require(_managers[i] > _managers[i-1]);
        }
        managerInfo=ManagerInfo(getManagerNumber(length,ratio,1e2),_expirationTime,_managers);
        _ratio=ratio;
    }
    
    //设置手续费比例合约地址
    function setFeeRateProvider(address _feeRateProvider,bytes memory signatures) external nonReentrant{
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
        bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.setFeeRateProvider.selector, _feeRateProvider,new bytes(0)));
        for (uint i;i<managerNumber;++i) {
             (t,j,v, r, s) = signatureSplit(signatures, i);
            require(t >expirationTime);//验证是否过期
            //获取签名的明文数据来恢复地址信息，其中明文数据是数据datahash和签名时间再次hash完成
            currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
            require(currentOwner > lastOwner);//保证账户不会重复
            require(currentOwner==managers[j]);
            lastOwner = currentOwner;
        }
        feeRateProvider=_feeRateProvider;
    }

    //设置手续费的开关
    function setFeeEnabled(bool _feeEnabled,bytes memory signatures) external nonReentrant{
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
        bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.setFeeEnabled.selector, _feeEnabled,new bytes(0)));
        for (uint i;i<managerNumber;++i) {
             (t,j,v, r, s) = signatureSplit(signatures, i);
            require(t >expirationTime);//验证是否过期
            //获取签名的明文数据来恢复地址信息，其中明文数据是数据datahash和签名时间再次hash完成
            currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
            require(currentOwner > lastOwner);//保证账户不会重复
            require(currentOwner==managers[j]);
            lastOwner = currentOwner;
        }
        feeEnabled=_feeEnabled;
    }

    //设置手续费地址
    function setFeeCollector(address _feeCollector,bytes memory signatures) external nonReentrant{
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
        bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.setFeeCollector.selector, _feeCollector,new bytes(0)));
        for (uint i;i<managerNumber;++i) {
             (t,j,v, r, s) = signatureSplit(signatures, i);
            require(t >expirationTime);//验证是否过期
            //获取签名的明文数据来恢复地址信息，其中明文数据是数据datahash和签名时间再次hash完成
            currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
            require(currentOwner > lastOwner);//保证账户不会重复
            require(currentOwner==managers[j]);
            lastOwner = currentOwner;
        }
        feeCollector=_feeCollector;
    }

    //通过手续费比例合约手续费开关返回OEM的当前手续费比例
    function getFeeRate(address mulOperatorAddr) external view returns (address _feeCollector, uint256 _feeRate) {
        if(!feeEnabled){
            return (address(0),0);
        }
        //直接访问 feeRateProvider 合约，返回对应OEM手续费比例
        uint256 minFeeRate = IFeeRateProvider(feeRateProvider).getFeeRate(mulOperatorAddr);
        uint256 feeRate = minFeeRate>0?minFeeRate:baseFeeRate;
        return (feeCollector, feeRate);
    }
}