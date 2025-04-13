// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;
import "./interfaces/IMultiSigProtocol.sol";
import "./interfaces/IMultiSigColdPro.sol";
import "./interfaces/IERC20Minimal.sol";
import "./interfaces/IMultiSigAgent.sol";
import "./interfaces/IAsset.sol";
import "./interfaces/IMerAggregator.sol";
import "./MultiSig.sol";
contract MultiSigColdStd is IMultiSigColdPro,MultiSig{
    constructor() {
    }
    /// @dev 资金平衡间隔时间
    uint public lastRebalanceTime;
    /// 商户配置 
    Merchant public merchant;
    /// 项目多签地址
    IMultiSigOperator public multiSigOperator;

    uint    public ownerStatus;
    address private _owner;
    mapping(address => uint256) public hotCoinMaxNum;
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
    
    /// @dev 初始化冷合约多签管理员列表
    /// @param data 商户配置
    /// @param _multiSigOperator 多签地址
    /// @param ratio 多签通过比例
    /// @param _managers 多签管理员
    function initManagers(Merchant calldata data,IMultiSigOperator _multiSigOperator,uint ratio,uint expirationTime,address[] calldata _managers) external onlyOwner{
        require(status!=1,"only init once");
        require(ratio >= 60 && ratio <= 100);
        status=1;
        multiSigOperator=_multiSigOperator;
        uint length=_managers.length;
        require(length>=3,"Manager cannot be less than three");
        for (uint i=1;i<length;++i) {
            require(_managers[i] > _managers[i-1]);
        }
        managerInfo=ManagerInfo(getManagerNumber(length,ratio,1e2),expirationTime,_managers);
        merchant = data;
        _ratio=ratio;
    }
    /// @dev 获取商户代理配置
    function getMerAgentConfigData() external view returns (uint256 agentRate,uint256 feeRate,address multiSigAgentAddr,address operatorFeeAddr){
        Merchant memory _merchant=merchant;
        return (
            _merchant.agentRate,
            _merchant.feeRate,
            _merchant.multiSigAgentAddr,
            multiSigOperator.getOperatorFeeAddr()
        );
    }

    //获取默认比例
    function getBaseFeeRate(uint256 feeRate) internal view {
        address mltiSigProtocolAddr = multiSigOperator.mltiSigProtocol();
        IMultiSigProtocol mltiSigProtocol = IMultiSigProtocol(mltiSigProtocolAddr);
        uint256 _baseFeeRate = mltiSigProtocol.baseFeeRate();
        require(feeRate >= _baseFeeRate ,"error");
    }

    // TODO 从总合约中获取OEM的手续费收取地址
    function getFeeRate() internal view returns (address _feeCollector,uint256 _feeRate){
        address mltiSigProtocolAddr = multiSigOperator.mltiSigProtocol();
        // 使用合约1的接口实例化合约1
        IMultiSigProtocol mltiSigProtocol = IMultiSigProtocol(mltiSigProtocolAddr);
        // 调用合约1的方法并返回结果
        return mltiSigProtocol.getFeeRate(multiSigOperator.getOperatorFeeAddr());
    }

    /// @dev 费用计算
    function _calculateCommission(uint256 _amount,address agentFeeAddr,Merchant memory _merchant,uint256 payProFeeRate) internal pure returns (
        Commission memory commission
    ) {
        // 商户 1% 100  总合约0.1%  50%
        //商户-总合约 = 0.9%
        uint256 merFeeRate = payProFeeRate>0?_merchant.feeRate - payProFeeRate:_merchant.feeRate;
        commission.paytocolCommission = payProFeeRate>0?(_amount * payProFeeRate) / 1e4:0;

        commission.totalCommission = (_amount * merFeeRate) / 1e4;
        //TODO 从运营多签获取总合约的手续费比例
        commission.agentCommission = agentFeeAddr != address(0)?(commission.totalCommission * _merchant.agentRate) / 1e2:0;
        commission.operatorCommission = commission.totalCommission - commission.agentCommission;
        commission.transBalHot = _amount - commission.totalCommission - commission.paytocolCommission;
    }
    
    /// @dev 资金平衡
    function balFundsToHot(address[] memory erc20s) external nonReentrant {
        Merchant memory _merchant=merchant;
        require(block.timestamp - lastRebalanceTime>_merchant.rebalanceTime, "Rebalance funds interval time limit");
        lastRebalanceTime=block.timestamp;
        bytes memory ethTransactions;
        uint hotBalance=_merchant.hotPool.balance;
        uint coldBalance=_merchant.coldPool.balance;
        uint amount=getHotBalanceFunds(hotBalance,coldBalance,hotCoinMaxNum[address(0)]);
        //获取payProtocol手续费比例与地址
        uint256 feeRate;
        address feeCollector;
        address agentFeeAddr = address(0);
        if(_merchant.multiSigAgentAddr!=address(0)){
            agentFeeAddr=IMultiSigAgent(_merchant.multiSigAgentAddr).getAgentFeeAddr();
        }
        address operatorFeeAddr=multiSigOperator.getOperatorFeeAddr();
        (feeCollector, feeRate)=getFeeRate();
        /// Tokens are transferred to the hot contract
        if(amount > 0){
            Commission memory commission = _calculateCommission(amount,agentFeeAddr,_merchant,feeRate);
            ethTransactions=abi.encodePacked(ethTransactions,_merchant.hotPool,commission.transBalHot);
            ethTransactions=abi.encodePacked(ethTransactions,operatorFeeAddr,commission.operatorCommission);
            if(agentFeeAddr!= address(0)){
                ethTransactions=abi.encodePacked(ethTransactions,agentFeeAddr,commission.agentCommission);
            }
            if(feeCollector!= address(0) && commission.paytocolCommission > 0){
                ethTransactions=abi.encodePacked(ethTransactions, feeCollector, commission.paytocolCommission);
            }
            emit TransferCommissionLogs(address(0), commission.totalCommission, commission.agentCommission, commission.operatorCommission, commission.transBalHot);
            IAsset(_merchant.coldPool).sendEths(ethTransactions);
        }
        bytes memory erc20Transactions;
        for(uint i; i<erc20s.length; ++i) {
            hotBalance = _balance(erc20s[i],_merchant.hotPool);
            coldBalance=_balance(erc20s[i],_merchant.coldPool);
            {
                address erc20 = erc20s[i];
                /// Calculate the balance that needs to be transferred to the hot contract
                amount = getHotBalanceFunds(hotBalance,coldBalance, hotCoinMaxNum[erc20]);
            }
            /// Tokens are transferred to the merchant hot contract
            if(amount > 0){
                /// commission amount
                Commission memory commission = _calculateCommission(amount,agentFeeAddr,_merchant, feeRate);
                /// The balance funds transferred to the hot contract, after deducting the funds after continuing to pay
                erc20Transactions=abi.encodePacked(
                    erc20Transactions,erc20s[i],abi.encodeWithSelector(0xa9059cbb, _merchant.hotPool, commission.transBalHot)
                );
                /// transfer fee
                erc20Transactions=abi.encodePacked(
                    erc20Transactions,erc20s[i],abi.encodeWithSelector(0xa9059cbb, operatorFeeAddr, commission.operatorCommission)
                );
                if(agentFeeAddr!= address(0)){
                    erc20Transactions=abi.encodePacked(
                        erc20Transactions,erc20s[i],abi.encodeWithSelector(0xa9059cbb, agentFeeAddr, commission.agentCommission)
                    );
                }
                if(feeCollector!= address(0)  && commission.paytocolCommission > 0){
                    erc20Transactions=abi.encodePacked(
                        erc20Transactions,erc20s[i],abi.encodeWithSelector(0xa9059cbb, feeCollector,commission.paytocolCommission)
                    );
                }
                emit TransferCommissionLogs(erc20s[i], commission.totalCommission, commission.agentCommission, commission.operatorCommission, commission.transBalHot);
            }
        }
        if(erc20Transactions.length > 0){
            IAsset(_merchant.coldPool).sendErc20(erc20Transactions);
        }
    }
    
    function _balance(address _token,address holder) internal view returns (uint256) {
        (bool success, bytes memory data) = _token.staticcall(
            abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, holder)
        );
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @dev 资金占比计算
    function getHotBalanceFunds(uint256 hotErc20BalanceOf,uint256 coldErc20BalanceOf,uint256 hotCoinMaxBal) internal pure returns(uint256 hotTransferErc20BalanceOf) {
        assembly {
            hotTransferErc20BalanceOf := 0
            if gt (hotCoinMaxBal,hotErc20BalanceOf){
                hotTransferErc20BalanceOf := sub(hotCoinMaxBal,hotErc20BalanceOf)
            }
            if gt (hotTransferErc20BalanceOf, 0) {
                if gt (hotTransferErc20BalanceOf,coldErc20BalanceOf) {
                    hotTransferErc20BalanceOf := coldErc20BalanceOf
                }
            }
            if eq (hotCoinMaxBal, 0) {
                hotTransferErc20BalanceOf := coldErc20BalanceOf
            }
        }
    }
   
    function setRebalanceTime(uint rebalanceTime,bytes memory signatures) external {
        ManagerInfo memory _managerInfo=managerInfo;
        uint managerNumber= _managerInfo.managerNumber;
        uint expirationTime= block.timestamp-_managerInfo.expirationTime;
        address[] memory managers=_managerInfo.managers;
        bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.setRebalanceTime.selector, rebalanceTime,new bytes(0)));
        address lastOwner = address(0);
        address currentOwner;
        uint t;uint8 j;uint8 v;bytes32 r;bytes32 s;
        for (uint i;i<managerNumber;++i) {
            (t,j,v, r, s) = signatureSplit(signatures, i);
            require(t > expirationTime);
            currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
            require(currentOwner > lastOwner);
            require(currentOwner==managers[j]);
            lastOwner = currentOwner;
        }
        merchant.rebalanceTime = rebalanceTime;
    }
    
    // @dev 修改hotpool地址
    function setHotPool(address payable hotPool,bytes memory signatures) external {
        ManagerInfo memory _managerInfo=managerInfo;
        uint managerNumber= _managerInfo.managerNumber;
        uint expirationTime= block.timestamp-_managerInfo.expirationTime;
        address[] memory managers=_managerInfo.managers;
        bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.setHotPool.selector, hotPool,new bytes(0)));
        address lastOwner = address(0);
        address currentOwner;
        uint t;uint8 j;uint8 v;bytes32 r;bytes32 s;
        for (uint i;i<managerNumber;++i) {
            (t,j,v, r, s) = signatureSplit(signatures, i);
            require(t > expirationTime);
            currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
            require(currentOwner > lastOwner);
            require(currentOwner==managers[j]);
            lastOwner = currentOwner;
        }
        merchant.hotPool = hotPool;
    }
    
    // @dev 
    function setHotCoinMaxNum(address erc20,uint256 maxNum,bytes memory signatures) external {
        ManagerInfo memory _managerInfo=managerInfo;
        uint managerNumber= _managerInfo.managerNumber;
        uint expirationTime= block.timestamp-_managerInfo.expirationTime;
        address[] memory managers=_managerInfo.managers;
        bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.setHotCoinMaxNum.selector, erc20, maxNum,new bytes(0)));
        address lastOwner = address(0);
        address currentOwner;
        //uint t;uint8 j;uint8 v;bytes32 r;bytes32 s;
        for (uint i;i<managerNumber;++i) {
            (uint t,uint8 j,uint8 v,bytes32 r,bytes32 s) = signatureSplit(signatures, i);
            require(t > expirationTime);
            currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
            require(currentOwner > lastOwner);
            require(currentOwner==managers[j]);
            lastOwner = currentOwner;
        }
        hotCoinMaxNum[erc20] = maxNum;
    }

    function setAgentRateAndFeeRate(uint agentRate,uint feeRate,bytes memory signatures) external {
        {
            getBaseFeeRate(feeRate);
            bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.setAgentRateAndFeeRate.selector, agentRate, feeRate, new bytes(0)));
            ManagerInfo memory _managerInfo=managerInfo;
            uint managerNumber= _managerInfo.managerNumber;
            uint expirationTime= block.timestamp-_managerInfo.expirationTime;
            address[] memory managers=_managerInfo.managers;
            address lastOwner = address(0);
            address currentOwner;
            uint t;uint8 j;uint8 v;bytes32 r;bytes32 s;
            for (uint i;i<managerNumber;++i) {
                (t,j,v, r, s) = signatureSplit(signatures, i);
                require(t > expirationTime);
                currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
                require(currentOwner > lastOwner);
                require(currentOwner==managers[j]);
                lastOwner = currentOwner;
            }
            (,uint _expirationTime,address[] memory operatorManagers)=multiSigOperator.getManagerInfo();
            (t,j,v, r, s) = signatureSplit(signatures, managerNumber);
            require(t>_expirationTime);
            currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
            //The Web3pay administrator is required to participate in a vote
            require(currentOwner==operatorManagers[j],"operator Manager Error");
        }

        merchant.agentRate =agentRate;
        merchant.feeRate =feeRate;
    }
    function setMultiSigAgentAddr(address multiSigAgentAddr,bytes memory signatures) external {
        bytes32 dataHash=_getTransactionHash(abi.encodeWithSelector(this.setMultiSigAgentAddr.selector,multiSigAgentAddr,new bytes(0)));
        (uint operatorManagerNumber,uint _expirationTime,address[] memory operatorManagers)=multiSigOperator.getManagerInfo();
        uint expirationTime= block.timestamp-_expirationTime;
        address lastOwner = address(0);
        address currentOwner;
        uint t;uint8 j;uint8 v;bytes32 r;bytes32 s;
        for (uint i;i<operatorManagerNumber;++i) {
            (t,j,v, r, s) = signatureSplit(signatures, i);
            require(t > expirationTime);
            currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
            require(currentOwner > lastOwner);
            require(currentOwner==operatorManagers[j]);
            lastOwner = currentOwner;
        }
        merchant.multiSigAgentAddr=multiSigAgentAddr;
    }
    
    function merAggregatorSetTokens(uint managerIndex,IMerAggregator merAggregator,address[] memory _tokens) external{
        require(managerInfo.managers[managerIndex]==msg.sender,"only manager");
        merAggregator.setTokens(_tokens);
    }
}