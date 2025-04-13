// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;
import "./interfaces/IMultiSigProtocol.sol";
import "./interfaces/IMultiSigAgent.sol";
import "./interfaces/IMultiSigOperator.sol";
import "./interfaces/IMultiSigColdPro.sol";
import "./interfaces/IMultiSigColdLite.sol";
import "./interfaces/IMultiSigHotPro.sol";
import "./interfaces/IAsset.sol";
import "./interfaces/IMerAggregator.sol";
import "./interfaces/ITemplateFactory.sol";

contract TemplateFactory is ITemplateFactory{
    
    TemplAddr public templAddr;
    uint public status;
    mapping (uint256=>OrgConfig) public orgConfig;

    constructor() {
    }

    function ins(
        uint256 t,
        OrgConfig calldata _orgConfig
    ) external  {
        require(_orgConfig.is_setup == true, "error1111111");
        require(orgConfig[t].is_setup == false, "error");
        orgConfig[t] = _orgConfig;
    }

    //所有合约发布完成再初始化所有模板地址
    function initContract(
        address _mltiSigOperator,
        address _mltiSigAgent,
        address _multiSigColdPro,
        address _multiSigHotPro,
        address _multiSigColdStd,
        address _multiSigColdLite,
        address _coldContract,
        address _hotContract,
        address _merAggregator
    ) external {
        require(status==0, "only init once");
        status = 1;
        TemplAddr memory _templAddr=templAddr;
        _templAddr.mltiSigOperator = _mltiSigOperator;
        _templAddr.mltiSigAgent = _mltiSigAgent;
        _templAddr.multiSigColdPro = _multiSigColdPro;
        _templAddr.multiSigHotPro = _multiSigHotPro;
        _templAddr.multiSigColdStd = _multiSigColdStd;
        _templAddr.multiSigColdLite = _multiSigColdLite;
        _templAddr.coldContract = _coldContract;
        _templAddr.hotContract = _hotContract;
        _templAddr.merAggregator = _merAggregator;
    }

    /// @dev 一键生成代理
    function createAgent(
        uint ratio,
        uint expirationTime,
        address _agentFeeAddr,
        address[] memory _managers,
        OrgConfig calldata _orgConfig
    ) external returns (address merchantAgent){
        TemplAddr memory _templAddr=templAddr;
        require(_templAddr.mltiSigAgent!=address(0), "only init once");
        require(orgConfig[_orgConfig.org_id].is_setup == false, "error");
        require(_orgConfig.is_setup == true, "error");
        merchantAgent=_cloneDeterministic(_templAddr.mltiSigAgent,_orgConfig.salt);
        IMultiSigAgent(merchantAgent).initManagers(ratio,expirationTime,_agentFeeAddr,_managers);
        orgConfig[_orgConfig.org_id] = _orgConfig;
    }

    /// @dev 一键生成商户专业版
    function createMerchantPro(
        MerInitConfig calldata config,
        Merchant calldata data,//商户链上配置（手续费比例，平衡间隔时间，代理手续费比例，热合约地址，冷合约地址，代理多签地址）
        OrgConfig calldata _orgConfig
    ) external {
        TemplAddr memory _templAddr=templAddr;
        require(_templAddr.mltiSigOperator!=address(0));
        IMultiSigOperator _mltiSigOperator = IMultiSigOperator(_templAddr.mltiSigOperator);
        (,,address[] memory xManagers)=IMultiSigOperator(_mltiSigOperator).getManagerInfo();
        require(xManagers[config.index]==msg.sender,"error");
        require(orgConfig[_orgConfig.org_id].is_setup == false, "error");
        require(_orgConfig.is_setup == true, "error");
        //TODO 通过运营商多签（mltiSigOperator）来获取总合约的手续费比例，判断最低收费标准，data.feeRate
        getBaseFeeRate(_mltiSigOperator, data.feeRate);
        
        address multiSigColdProAddr = _cloneDeterministic(_templAddr.multiSigColdPro,_orgConfig.salt);
        address multiSigHotProAddr = _cloneDeterministic(_templAddr.multiSigHotPro,_orgConfig.salt);
        address coldContractAddr = _cloneDeterministic(_templAddr.coldContract,_orgConfig.salt);
        address hotContractAddr = _cloneDeterministic(_templAddr.multiSigColdPro,_orgConfig.salt);
        address merAggregatorAddr = _cloneDeterministic(_templAddr.merAggregator,_orgConfig.salt);
        _createAccount(config.accountCode,_orgConfig.salt);
        _initializeContractPro(config, data, multiSigColdProAddr, multiSigHotProAddr, coldContractAddr, hotContractAddr, merAggregatorAddr, _mltiSigOperator);
        orgConfig[_orgConfig.org_id] = _orgConfig;
    }

     /// @dev 一键生成商户标准
    function createMerchantStd(
        MerInitConfig calldata config,
        Merchant calldata data,//商户链上配置（手续费比例，平衡间隔时间，代理手续费比例，热合约地址，冷合约地址，代理多签地址）
        OrgConfig calldata _orgConfig
    ) external {
        TemplAddr memory _templAddr=templAddr;
        require(_templAddr.mltiSigOperator!=address(0));
        IMultiSigOperator _mltiSigOperator = IMultiSigOperator(_templAddr.mltiSigOperator);
        (,,address[] memory xManagers)=IMultiSigOperator(_mltiSigOperator).getManagerInfo();
        require(xManagers[config.index]==msg.sender,"error");
        require(orgConfig[_orgConfig.org_id].is_setup == false, "error");
        require(_orgConfig.is_setup == true, "error");
        //TODO 通过运营商多签（mltiSigOperator）来获取总合约的手续费比例，判断最低收费标准，data.feeRate
        getBaseFeeRate(_mltiSigOperator, data.feeRate);

        address multiSigColdStdAddr = _cloneDeterministic(_templAddr.multiSigColdStd,_orgConfig.salt);
        address coldContractAddr = _cloneDeterministic(_templAddr.coldContract,_orgConfig.salt);
        address merAggregatorAddr = _cloneDeterministic(_templAddr.merAggregator,_orgConfig.salt);
        _createAccount(config.accountCode,_orgConfig.salt);
        _initializeContractStd(config, data, multiSigColdStdAddr, coldContractAddr, merAggregatorAddr, _mltiSigOperator);
        orgConfig[_orgConfig.org_id] = _orgConfig;
    }

    /// @dev 一键生成商户Lite
    function createMerchantLite(
        MerInitConfig calldata config,
        MerchantLite calldata data,//商户链上配置（手续费比例，平衡间隔时间，代理手续费比例，热合约地址，冷合约地址，代理多签地址）
        OrgConfig calldata _orgConfig
    ) external {
        TemplAddr memory _templAddr=templAddr;
        require(_templAddr.mltiSigOperator!=address(0));
        IMultiSigOperator _mltiSigOperator = IMultiSigOperator(_templAddr.mltiSigOperator);
        (,,address[] memory xManagers)=IMultiSigOperator(_mltiSigOperator).getManagerInfo();
        require(xManagers[config.index]==msg.sender,"error");
        require(orgConfig[_orgConfig.org_id].is_setup == false, "error");
        require(_orgConfig.is_setup == true, "error");
        //TODO 通过运营商多签（mltiSigOperator）来获取总合约的手续费比例，判断最低收费标准，data.feeRate
        getBaseFeeRate(_mltiSigOperator, data.feeRate);
        // 2创建子合约模板
        // 3初始化配置多签管理员multiSigCold.initManagers:
        // 4初始化配置多签管理员multiSigHot.initMultiSigCold
        // 5修改冷合约的owner为冷合约多签地址
        // 6 修改热合约owner为热合约多签地址
        // 7 初始化商户操作
        // address multiSigColdAddr = predicteds[0];
        // address coldAddr = predicteds[1];
        // address helperAddr = predicteds[2];
        address multiSigColdLiteAddr = _cloneDeterministic(_templAddr.multiSigColdLite,_orgConfig.salt);
        address coldContractAddr = _cloneDeterministic(_templAddr.coldContract,_orgConfig.salt);
        address merAggregatorAddr = _cloneDeterministic(_templAddr.merAggregator,_orgConfig.salt);
        _createAccount(config.accountCode,_orgConfig.salt);

        IMultiSigColdLite(multiSigColdLiteAddr).initOwner();
        IMultiSigColdLite(multiSigColdLiteAddr).initManagers(data,_mltiSigOperator);
        IAsset(coldContractAddr).initOwner(multiSigColdLiteAddr);
        IMerAggregator(merAggregatorAddr).initConfig(config.tokens, payable(coldContractAddr), multiSigColdLiteAddr);
        orgConfig[_orgConfig.org_id] = _orgConfig;
    }

    function _initializeContractPro (
        MerInitConfig calldata config,
        Merchant calldata data,
        address multiSigColdProAddr,
        address multiSigHotProAddr,
        address coldContractAddr,
        address hotContractAddr,
        address merAggregatorAddr,
        IMultiSigOperator _mltiSigOperator
    ) internal {
        // 1 部署所有合约
        // 2 创建子合约模板
        // 3 初始化配置多签管理员multiSigCold.initManagers:
        // 4 初始化配置多签管理员multiSigHot.initMultiSigCold
        // 5 修改冷合约的owner为冷合约多签地址
        // 6 修改热合约owner为热合约多签地址
        // 7 初始化商户操作
        IMultiSigColdPro _multiSigColdPro = IMultiSigColdPro(multiSigColdProAddr);
        IMultiSigColdPro(multiSigColdProAddr).initOwner();
        IMultiSigColdPro(multiSigColdProAddr).initManagers(data, _mltiSigOperator, config.coldRatio, config.expirationTime, config.coldManagers);
        IMultiSigHotPro(multiSigHotProAddr).initOwner();
        IMultiSigHotPro(multiSigHotProAddr).initMultiSigCold(_multiSigColdPro, config.expirationTime, config.hotManagers);
        IAsset(coldContractAddr).initOwner(multiSigColdProAddr);
        IAsset(hotContractAddr).initOwner(multiSigHotProAddr);
        IMerAggregator(merAggregatorAddr).initConfig(config.tokens, payable(coldContractAddr), multiSigColdProAddr);
    }
    
    
    function _initializeContractStd (
        MerInitConfig calldata config,
        Merchant calldata data,
        address multiSigColdStdAddr,
        address coldContractAddr,
        address merAggregatorAddr,
        IMultiSigOperator _mltiSigOperator
    ) internal {
        // 1 部署所有合约
        // 2 创建子合约模板
        // 3 初始化配置多签管理员multiSigCold.initManagers:
        // 4 修改冷合约的owner为冷合约多签地址
        // 5 初始化商户操作
        IMultiSigColdPro(multiSigColdStdAddr).initOwner();
        IMultiSigColdPro(multiSigColdStdAddr).initManagers(data, _mltiSigOperator, config.coldRatio, config.expirationTime, config.coldManagers);
        IAsset(coldContractAddr).initOwner(multiSigColdStdAddr);
        IMerAggregator(merAggregatorAddr).initConfig(config.tokens, payable(coldContractAddr), multiSigColdStdAddr);
    }

    function getBaseFeeRate(IMultiSigOperator _mltiSigOperator, uint256 _feeRate) internal view {
        address mltiSigProtocolAddr = _mltiSigOperator.mltiSigProtocol();
        IMultiSigProtocol mltiSigProtocol = IMultiSigProtocol(mltiSigProtocolAddr);
        uint256 _baseFeeRate = mltiSigProtocol.baseFeeRate();
        require(_feeRate >= _baseFeeRate ,"error");
    }

    function cloneAccounts(address impl,bytes32[] memory salts) external returns (address[] memory predicteds) {
        uint length=salts.length;
        predicteds=new address[](length);
        for(uint i;i<length;++i){
            predicteds[i]=_cloneDeterministic(impl,salts[i]);
        }
    }
    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
     //以最小代理合约方式，为了以不可变的方式简单、廉价地克隆合约功能，
     //该标准指定了一个最小字节码实现，将所有调用委托给已知的固定地址implementation
     //该方式部署成本低廉（部署克隆的 Gas 成本较低）
    function _cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create2(0, 0x09, 0x37, salt)
        }
    }
	function cloneAccount(address impl, bytes32 salt) external returns (address instance) {
        assembly {
            mstore(0x00, or(shr(0xe8, shl(0x60, impl)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            mstore(0x20, or(shl(0x78, impl), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create2(0, 0x09, 0x37, salt)
        }
    }
    //通过已知的合约字节码来创建合约
    //bytecode是合约字节码，saltHash是用于生成唯一地址的唯一盐
    function createAccount(bytes memory bytecode,bytes32 saltHash) external{
        assembly {
            pop(create2(0, add(bytecode, 0x20), mload(bytecode), saltHash))
        }
    }
    function _createAccount(bytes memory bytecode,bytes32 saltHash) internal{
        assembly {
            pop(create2(0, add(bytecode, 0x20), mload(bytecode), saltHash))
        }
    }
}