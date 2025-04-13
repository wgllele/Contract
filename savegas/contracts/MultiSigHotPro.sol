// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;
import "./interfaces/IERC20Minimal.sol";
import "./interfaces/IAsset.sol";
import "./MultiSig.sol";
contract MultiSigHotPro is MultiSig{
    constructor() {
    }
    //为了首次初始化操作使用，如果等于10代表已经初始化过
    uint public ownerStatus;
    address private _owner;

    error OwnableUnauthorizedAccount(address account);

    function initOwner() external{
        require(ownerStatus!=1,"only init once");
        ownerStatus=1;
        _owner = msg.sender;
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
    //多签冷合约地址
    address public multiSigColdPro;
    //初始化配置信息，包括多签冷合约地址，多签有效期限，多签管理员信息，多签管理员地址要保证有序，地址顺序是从小到大
    function initMultiSigCold(address _multiSigColdPro,uint expirationTime,address[] memory _managers) external onlyOwner{
        require(status!=1,"only init once");
        status=1;
        multiSigColdPro=_multiSigColdPro;
        uint length=_managers.length;
        require(length>=2,"Manager cannot be less than two");
        for (uint i=1;i<length;++i) {
            require(_managers[i] > _managers[i-1]);
        }
        managerInfo=ManagerInfo(length,expirationTime,_managers);
    }
    //设置多签的签名有效时间
    //expTime为签名有效时间，单位为秒
    //signatures是签名数据
    //多签功能参考MultiSig.setManagerExpTime，更多信息参考MultiSig.setManagerExpTime
    function setManagerExpTime(uint expTime,bytes memory signatures) external override nonReentrant{
        (uint managerNumber,uint _expirationTime,address[] memory managers)=MultiSig(multiSigColdPro).getManagerInfo();
        uint expirationTime= block.timestamp-_expirationTime;
        address lastOwner = address(0);
        address currentOwner;
        uint t;uint8 j;uint8 v;bytes32 r;bytes32 s;
        bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.setManagerExpTime.selector, expTime,new bytes(0)));
        for (uint i;i<managerNumber;++i) {
            (t,j,v, r, s) = signatureSplit(signatures, i);
            require(t > expirationTime );
            currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
            require(currentOwner > lastOwner);
            require(currentOwner==managers[j]);
            lastOwner = currentOwner;
        }
        managerInfo.expirationTime=expTime;
    }
    //添加新的管理员
    //_target为新的管理员地址，_index为提前链下计算好的在管理员数组列表中插入的位置
    //signatures是签名数据
    //多签功能参考MultiSig.addManager，更多信息参考MultiSig.addManager
    function addManager(address _target,uint256 _index,bytes memory signatures) external override nonReentrant{
        {
            (uint coldManagerNumber,uint _coldeExpirationTime,address[] memory coldManagers)=MultiSig(multiSigColdPro).getManagerInfo();
            bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.addManager.selector,_target,_index,new bytes(0)));
            uint expirationTime= block.timestamp-_coldeExpirationTime;
            address lastOwner = address(0);
            address currentOwner;
            uint t;uint8 j;uint8 v;bytes32 r;bytes32 s;
            for (uint i;i<coldManagerNumber;++i) {
                (t,j,v, r, s) = signatureSplit(signatures, i);
                require(t > expirationTime );
                currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
                require(currentOwner > lastOwner);
                require(currentOwner==coldManagers[j]);
                lastOwner = currentOwner;
            }
        }
        ManagerInfo memory _managerInfo=managerInfo;
        address[] memory managers=_managerInfo.managers;
        uint length=managers.length;
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
        managerInfo.managers.push();
        managers=managerInfo.managers;
        for(uint i=length;i>_index;--i){
            managers[i]=managers[i-1];
        }
        managers[_index]=_target;
        managerInfo.managers=managers;
        managerInfo.managerNumber=managers.length;
    }
    //删除管理员
    //_target为需要删除的管理员地址，_index为提前链下计算好的在管理员数组列表中的位置
    //signatures是签名数据
    //多签功能参考MultiSig.rmManager，更多信息参考MultiSig.rmManager
    function rmManager(address _target,uint256 _index,bytes memory signatures) external override nonReentrant{
        {
            (uint coldManagerNumber,uint _coldeExpirationTime,address[] memory coldManagers)=MultiSig(multiSigColdPro).getManagerInfo();
            address lastOwner = address(0);
            address currentOwner;
            uint t;uint8 j;uint8 v;bytes32 r;bytes32 s;
            bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.rmManager.selector,_target,_index,new bytes(0)));
            uint expirationTime= block.timestamp-_coldeExpirationTime;
            for (uint i;i<coldManagerNumber;++i) {
                (t,j,v, r, s) = signatureSplit(signatures, i);
                require(t > expirationTime );
                currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
                require(currentOwner > lastOwner);
                require(currentOwner==coldManagers[j]);
                lastOwner = currentOwner;
            }
        }
        ManagerInfo memory _managerInfo=managerInfo;
        address[] memory managers=_managerInfo.managers;
        uint length=managers.length;
        require(length > 2 , "Manager cannot be less than two");
        require(_index<length && managers[_index]==_target, "address is not exist");
        length=length-1;
        for (uint i=_index; i < length; ++i) {
            managers[i]=managers[i+1];
        }
        managerInfo.managers=managers;
        managerInfo.managers.pop();
        managerInfo.managerNumber=length;
    }
    ///用户提现操作
    function withdrawAsset(address from,address[] calldata to,address erc20s,uint[] calldata amounts,bytes memory signatures) external payable{
        {
            //获取管理员信息
            ManagerInfo memory _managerInfo=managerInfo;
            //获取需要多签的签名数量
            uint managerNumber= _managerInfo.managerNumber;
            //获取签名有效期限(截止时间，单位为妙)
            uint expirationTime= block.timestamp-_managerInfo.expirationTime;
            //获多签管理员名单列表
            address[] memory managers=_managerInfo.managers;
            //签名的原始数据datahash，满足EIP712并包括合约nonce等信息
            bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.withdrawAsset.selector,from,to,erc20s,amounts,new bytes(0)));
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
        require(to.length == amounts.length, "not valid param");
        bytes memory ethTransactions;
        if(erc20s == address(0)){
            uint ethLenth=to.length;
            for(uint i; i<ethLenth;++i) {
                if(amounts[i]>0){
                    ethTransactions=abi.encodePacked(ethTransactions,to[i],amounts[i]);
                }
            }
            if(ethTransactions.length > 0){
                IAsset(from).sendEths(ethTransactions);
            }
        }else{
            bytes memory erc20Transactions;
            uint ercLenth=to.length;
            if(ercLenth>0){
                for(uint i; i<ercLenth;++i) {
                    if(amounts[i]>0){
                        erc20Transactions=abi.encodePacked(
                            erc20Transactions,erc20s,abi.encodeWithSelector(0xa9059cbb, to[i],amounts[i])
                        );
                    }
                }
                if(erc20Transactions.length > 0){
                    IAsset(from).sendErc20(erc20Transactions);
                }
            }
        }
    }

    function batchWithdrawAsset(address from,address[] calldata to,address[] calldata erc20s,uint[] calldata amounts,bytes memory signatures) external payable{
        {
            ManagerInfo memory _managerInfo=managerInfo;
            uint managerNumber= _managerInfo.managerNumber;
            uint expirationTime= block.timestamp-_managerInfo.expirationTime;
            address[] memory managers=_managerInfo.managers;
            bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.batchWithdrawAsset.selector,from,to,erc20s,amounts,new bytes(0)));
            address lastOwner = address(0);
            address currentOwner;
            uint t;
            uint8 j;
            uint8 v;
            bytes32 r;
            bytes32 s;
            for (uint i;i<managerNumber;++i) {
                (t,j,v, r, s) = signatureSplit(signatures, i);
                require(t >expirationTime);
                currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
                require(currentOwner > lastOwner);
                require(currentOwner==managers[j]);
                lastOwner = currentOwner;
            }
        }
        require(erc20s.length == amounts.length, "not valid param");
        require(to.length == amounts.length, "not valid param");
        bytes memory ethTransactions;
        bytes memory erc20Transactions;
        uint recLenth=erc20s.length;
        for(uint j; j<recLenth;++j){
            if(erc20s[j] == address(0)){
                if(amounts[j]>0){
                    ethTransactions=abi.encodePacked(ethTransactions,to[j],amounts[j]);
                }
            }else{
                if(amounts[j]>0){
                    erc20Transactions=abi.encodePacked(
                        erc20Transactions,erc20s[j],abi.encodeWithSelector(0xa9059cbb, to[j],amounts[j])
                    );
                }
            }
        }
        
        if(ethTransactions.length > 0){
            IAsset(from).sendEths(ethTransactions);
        }
        if(erc20Transactions.length > 0){
            IAsset(from).sendErc20(erc20Transactions);
        }
    }
}