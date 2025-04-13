// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;
import "./lib/ReentrancyGuardTransient.sol";
import "./interfaces/IMultiSig.sol";
//多签抽象共用合约，被冷合约多签和热合约多签继承的公用方法
abstract contract MultiSig is ReentrancyGuardTransient,IMultiSig{
    //多签合约管理员信息
    struct ManagerInfo {
        uint256 managerNumber; /// 至少需要多签的签名数量
        uint256 expirationTime;/// 签名有效期限
        address[] managers; ///多签管理员名单列表，地址是有序的，顺序是从小到大
    }
    ManagerInfo managerInfo;
    //为了首次初始化操作使用，如果等于10代表已经初始化过
    uint public status;
    /// 至少需要多签的签名比例，用于计算至少需要多签的签名数量
    uint _ratio;
    function getManagerRatio() external view returns(uint){
        return _ratio;
    }
    function getManagerInfo() external virtual view returns(uint managerNumber,uint expirationTime,address[] memory managers){
        ManagerInfo memory _managerInfo=managerInfo;
        managerNumber= _managerInfo.managerNumber;
        expirationTime= _managerInfo.expirationTime;
        managers=_managerInfo.managers;
    }
    //通过多签的签名比例计算出至少需要多签的签名数量
    function getManagerNumber(uint managerLength,uint ratio,uint base)internal pure returns (uint managerNumber) {
        assembly {
            let numerator := mul(managerLength, ratio)
            let addendum  := sub(base, 1)
            managerNumber := div(add(numerator, addendum), base)
        }
    }
    //设置多签的签名比例
    //ratio为签名比例，精度为100，比如ratio为70代表百分之七十(70%)
    //signatures是签名数据
    function setManagerRatio(uint ratio,bytes memory signatures) external virtual nonReentrant{
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
        bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.setManagerRatio.selector, ratio,new bytes(0)));
        for (uint i;i<managerNumber;++i) {
             (t,j,v, r, s) = signatureSplit(signatures, i);
            require(t >expirationTime);//验证是否过期
            //获取签名的明文数据来恢复地址信息，其中明文数据是数据datahash和签名时间再次hash完成
            currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
            require(currentOwner > lastOwner);//保证账户不会重复
            require(currentOwner==managers[j]);
            lastOwner = currentOwner;
        }
        managerNumber=getManagerNumber(managers.length,ratio,1e2);
        require(managerNumber>=2,"Manager cannot be less than two");
        managerInfo.managerNumber=managerNumber;
        _ratio=ratio;
    }
    //设置多签的签名有效时间
    //_expirationTime为签名有效时间，单位为秒
    //signatures是签名数据
    function setManagerExpTime(uint _expirationTime,bytes memory signatures) external virtual nonReentrant{
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
        bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.setManagerExpTime.selector, _expirationTime,new bytes(0)));
        for (uint i;i<managerNumber;++i) {
             (t,j,v, r, s) = signatureSplit(signatures, i);
            require(t >expirationTime);//验证是否过期
            //获取签名的明文数据来恢复地址信息，其中明文数据是数据datahash和签名时间再次hash完成
            currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
            require(currentOwner > lastOwner);//保证账户不会重复
            require(currentOwner==managers[j]);
            lastOwner = currentOwner;
        }
        managerInfo.expirationTime=_expirationTime;
    }
    //添加新的管理员
    //_target为新的管理员地址，_index为提前链下计算好的在管理员数组列表中插入的位置
    //signatures是签名数据
    function addManager(address _target,uint256 _index,bytes memory signatures) external virtual nonReentrant{
        //获取管理员信息
        ManagerInfo memory _managerInfo=managerInfo;
        //获多签管理员名单列表
        address[] memory managers=_managerInfo.managers;
        //获取需要多签的签名数量
        uint managerNumber= _managerInfo.managerNumber;
        {
            //签名的原始数据datahash，满足EIP712并包括合约nonce等信息
            bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.addManager.selector, _target,_index,new bytes(0)));
            //获取签名有效期限(截止时间，单位为妙)
            uint expirationTime= block.timestamp-_managerInfo.expirationTime;
            //最近签名过的管理员地址，用于排重用途
            address lastOwner = address(0);
            //当前签名的管理员地址，用于验签用途
            address currentOwner;
            uint t;//签名的时间戳(秒为单位)
            uint8 j;//签名管理员在合约管理员信息的名单列表里面的位置(下标)
            uint8 v;//签名数据V
            bytes32 r;//签名数据R
            bytes32 s;//签名数据S
            for (uint i;i<managerNumber;++i) {
                (t,j,v, r, s) = signatureSplit(signatures, i);
                require(t >expirationTime);//验证是否过期
                //获取签名的明文数据来恢复地址信息，其中明文数据是数据datahash和签名时间再次hash完成
                currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
                require(currentOwner > lastOwner);//保证账户不会重复
                require(currentOwner==managers[j]);
                lastOwner = currentOwner;
            }
        }
        uint length=managers.length;
        //验证新添加地址的位置，保证顺序性
        if(_index==0){
            require(_target<managers[0]);
        }else if(_index<length){
            require(
                _target<managers[_index]&&
                _target>managers[_index-1]
            );
        }else{
            require(_index==length&&_target>managers[_index-1]);
        }
        //添加新的管理员空间
        managerInfo.managers.push();

        //重新赋值给临时内存变量managers，便于后面使用从而节省gas费用
        managers=managerInfo.managers;
        //从数组末尾向前遍列，后一位重新赋值为前一位数据直到需要插入数据的位置
        for(uint i=length;i>_index;--i){
            managers[i]=managers[i-1];
        }
        //插入数据位置替换为新添加的管理员
        managers[_index]=_target;
        managerInfo.managers=managers;
        //根据多签的签名比例，计算需要多签的签名数量进而重新设置多签的签名数量
        managerInfo.managerNumber=getManagerNumber(managers.length,_ratio,1e2);
    }
    //删除管理员
    //_target为需要删除的管理员地址，_index为提前链下计算好的在管理员数组列表中的位置
    //signatures是签名数据
    function rmManager(address _target,uint256 _index,bytes memory signatures) external virtual nonReentrant{
        //获取管理员信息
        ManagerInfo memory _managerInfo=managerInfo;
        //获多签管理员名单列表
        address[] memory managers=_managerInfo.managers;
        //获取需要多签的签名数量
        uint managerNumber= _managerInfo.managerNumber;
        {
            //签名的原始数据datahash，满足EIP712并包括合约nonce等信息
            bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.rmManager.selector,_target,_index,new bytes(0)));
            //获取签名有效期限(截止时间，单位为妙)
            uint expirationTime= block.timestamp-_managerInfo.expirationTime;
            //最近签名过的管理员地址，用于排重用途
            address lastOwner = address(0);
            //当前签名的管理员地址，用于验签用途
            address currentOwner;
            uint t;//签名的时间戳(秒为单位)
            uint8 j;//签名管理员在合约管理员信息的名单列表里面的位置(下标)
            uint8 v;//签名数据V
            bytes32 r;//签名数据R
            bytes32 s;//签名数据S
            for (uint i;i<managerNumber;++i) {
                (t,j,v, r, s) = signatureSplit(signatures, i);
                require(t >expirationTime);//验证是否过期
                //获取签名的明文数据来恢复地址信息，其中明文数据是数据datahash和签名时间再次hash完成
                currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
                require(currentOwner > lastOwner);//保证账户不会重复
                require(currentOwner==managers[j]);
                lastOwner = currentOwner;
            }
        }
        uint length=managers.length;
        require(length >= 3 , "Manager cannot be less than three");
        require(managers[_index]==_target, "address is not exist");
        length=length-1;
        //从需要删除的管理员数组列表中的位置开始遍列，前一位重新赋值为后一位的数据直到数组末尾
        for (uint i=_index; i<length; ++i) {
            managers[i]=managers[i+1];
        }
        managerInfo.managers=managers;
        managerInfo.managers.pop();
        //根据多签的签名比例，计算需要多签的签名数量进而重新设置多签的签名数量
        managerInfo.managerNumber=getManagerNumber(length,_ratio,1e2);
    }
    
    //用于防止签名重复使用
    uint256 public nonce;
    // keccak256(
    //     "EIP712Domain(uint256 chainId,address verifyingContract)"
    // );
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH = 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;
    
    //满足EIP712以防止多链重入
    function _getTransactionHash(bytes memory transactions) internal returns (bytes32 txHash) {
        txHash =keccak256(abi.encodePacked(bytes1(0x19),bytes1(0x01),_domainSeparator(),keccak256(abi.encode(transactions,nonce++))));
    }
    function getTransactionHash(bytes memory transactions) external view returns (bytes32 txHash) {
        txHash =keccak256(abi.encodePacked(bytes1(0x19),bytes1(0x01),_domainSeparator(),keccak256(abi.encode(transactions,nonce))));
    }
    function _domainSeparator() internal view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, chainId, this));
    }
    //解析签名数据
    //signatures是签名数据，pos是签名分割的位置
    //t;签名的时间戳(秒为单位)
    //j;签名管理员在合约管理员信息的名单列表里面的位置(下标)
    //v;签名数据V
    //r;签名数据R
    //s;签名数据S
    function signatureSplit(bytes memory signatures, uint256 pos) internal pure returns (
        uint t,uint8 j,uint8 v,bytes32 r,bytes32 s
    ) {
        assembly {
            let signaturePos := mul(0x62, pos)
            r := mload(add(signatures, add(signaturePos, 0x20)))
            s := mload(add(signatures, add(signaturePos, 0x40)))
            t := mload(add(signatures, add(signaturePos, 0x60)))
            j := byte(0, mload(add(signatures, add(signaturePos, 0x80))))
            v := byte(0, mload(add(signatures, add(signaturePos, 0x81))))
        }
    }
    //混淆txHash和签名期限t的hash，然后加入以太坊签名前缀串
    function getHashWithTimestamp(bytes32 txHash,uint t)internal pure returns (bytes32 digest) {
        bytes32 messageHash=keccak256(abi.encodePacked(txHash, t));
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32") // 32 is the bytes-length of messageHash
            mstore(0x1c, messageHash) // 0x1c (28) is the length of the prefix
            digest := keccak256(0x00, 0x3c) // 0x3c is the length of the prefix (0x1c) + messageHash (0x20)
        }
    }
}