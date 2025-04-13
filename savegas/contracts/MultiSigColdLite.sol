// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;
import "./interfaces/IMultiSigProtocol.sol";
import "./lib/ReentrancyGuardTransient.sol";
import "./interfaces/IMultiSigColdLite.sol";
import "./interfaces/IERC20Minimal.sol";
import "./interfaces/IMultiSigAgent.sol";
import "./interfaces/IMerAggregator.sol";
import "./interfaces/IAsset.sol";
import "./interfaces/IMultiSigOperator.sol";
import "./interfaces/IMultiSig.sol";

contract MultiSigColdLite is ReentrancyGuardTransient,IMultiSigColdLite{
    constructor() {
    }
    
    /// @dev 合约初始化状态
    uint public status;
    uint public ownerStatus;
    /// 商户配置 
    MerchantLite public merchant;
    /// 项目多签地址
    IMultiSigOperator public multiSigOperator;
    
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

    function initManagers(MerchantLite calldata data,IMultiSigOperator _multiSigOperator) external onlyOwner{
        require(status!=1,"only init once");
        status=1;
        multiSigOperator=_multiSigOperator;
        merchant = data;
    }

    function withdrawEmergency(address[] memory erc20s) external nonReentrant payable {
        MerchantLite memory _merchant=merchant;
        bytes memory ethTransactions;
        bytes memory erc20Transactions;
        // uint256 totalCommission;
        // uint256 agentCommission;
        // uint256 operatorCommission;
        // uint256 transBalHot;
        //获取payProtocol手续费比例与地址
        uint256 feeRate;
        address feeCollector;

        address agentFeeAddr = address(0);
        if(_merchant.multiSigAgentAddr!=address(0)){
            agentFeeAddr=IMultiSigAgent(_merchant.multiSigAgentAddr).getAgentFeeAddr();
        }
        address operatorFeeAddr=multiSigOperator.getOperatorFeeAddr();
        (feeCollector, feeRate)=getFeeRate();

        uint amount=_merchant.coldPool.balance;
        if(amount>0){
            Commission memory commission  = _calculateCommission(amount, agentFeeAddr, _merchant, feeRate);
            ethTransactions=abi.encodePacked(ethTransactions, _merchant.emergencyAddr, commission.transBalHot);
            ethTransactions=abi.encodePacked(ethTransactions, operatorFeeAddr, commission.operatorCommission);
            if(agentFeeAddr!= address(0)){
                ethTransactions=abi.encodePacked(ethTransactions, agentFeeAddr, commission.agentCommission);
            }
            if(feeCollector!= address(0) && commission.paytocolCommission > 0){
                ethTransactions=abi.encodePacked(ethTransactions, feeCollector, commission.paytocolCommission);
            }
            IAsset(_merchant.coldPool).sendEths(ethTransactions);
            emit TransferCommissionLogs(address(0), commission.totalCommission, commission.agentCommission, commission.operatorCommission, commission.transBalHot);
        }
        for(uint i; i<erc20s.length; ++i) {
            amount=_balance(erc20s[i],_merchant.coldPool);
            if(amount > 0){
                /// commission amount
                Commission memory commission = _calculateCommission(amount, agentFeeAddr, _merchant, feeRate);
                /// The balance funds transferred to the hot contract, after deducting the funds after continuing to pay
                erc20Transactions=abi.encodePacked(
                    erc20Transactions,erc20s[i],abi.encodeWithSelector(0xa9059cbb, _merchant.emergencyAddr, commission.transBalHot)
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
                        erc20Transactions,erc20s[i],abi.encodeWithSelector(0xa9059cbb, feeCollector, commission.paytocolCommission)
                    );
                }
                emit TransferCommissionLogs(erc20s[i], commission.totalCommission, commission.agentCommission, commission.operatorCommission, commission.transBalHot);
            }
        }
        if(erc20Transactions.length > 0){
            IAsset(_merchant.coldPool).sendErc20(erc20Transactions);
        }
    }
    /// @dev 获取商户代理配置
    function getMerAgentConfigData() external view returns (uint256 agentRate,uint256 feeRate,address multiSigAgentAddr,address operatorFeeAddr){
        MerchantLite memory _merchant=merchant;
        return (
            _merchant.agentRate,
            _merchant.feeRate,
            _merchant.multiSigAgentAddr,
            multiSigOperator.getOperatorFeeAddr()
        );
    }

    // 从总合约中获取OEM的手续费收取地址
    function getFeeRate() internal view returns (address _feeCollector,uint256 _feeRate){
        address mltiSigProtocolAddr = multiSigOperator.mltiSigProtocol();
        // 使用合约1的接口实例化合约1
        IMultiSigProtocol mltiSigProtocol = IMultiSigProtocol(mltiSigProtocolAddr);
        // 调用合约1的方法并返回结果
        return mltiSigProtocol.getFeeRate(multiSigOperator.getOperatorFeeAddr());
    }

    /// @dev 费用计算
    function _calculateCommission(uint256 _amount,address agentFeeAddr,MerchantLite memory _merchant,uint256 payProFeeRate) internal pure returns (
        Commission memory commission
    ) {
        uint256 merFeeRate = payProFeeRate>0?_merchant.feeRate - payProFeeRate:_merchant.feeRate;
        commission.paytocolCommission = payProFeeRate>0?(_amount * payProFeeRate) / 1e4:0;

        commission.totalCommission = (_amount * merFeeRate) / 1e4;
        //TODO 从运营多签获取总合约的手续费比例
        commission.agentCommission = agentFeeAddr != address(0)?(commission.totalCommission * _merchant.agentRate) / 1e2:0;
        commission.operatorCommission = commission.totalCommission - commission.agentCommission;
        commission.transBalHot = _amount - commission.totalCommission - commission.paytocolCommission;
    }
    
    function _balance(address _token,address holder) internal view returns (uint256) {
        (bool success, bytes memory data) = _token.staticcall(
            abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, holder)
        );
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    function merAggregatorSetTokens(IMerAggregator merAggregator,address[] calldata _tokens) external{
        MerchantLite memory _merchant=merchant;
        require(_merchant.emergencyAddr==msg.sender,"only manager");
        merAggregator.setTokens(_tokens);
    }
}