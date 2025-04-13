// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;
import "./interfaces/IMultiSigOperator.sol";
import "./interfaces/IProtocolFactory.sol";
import "./interfaces/ITemplateFactory.sol";

contract ProtocolFactory is IProtocolFactory{
    
    TemplContractAddr public templContractAddr;
    uint public status;

    constructor() {
    }

    //所有合约发布完成再初始化所有模板地址
    function initContract(
        address  _mltiSigProtocol,//总合约多签
        address _templateFactory,//OEM工厂合约
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
        TemplContractAddr memory _templAddr=templContractAddr;
        _templAddr.mltiSigProtocol = _mltiSigProtocol;
        _templAddr.templateFactory = _templateFactory;
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

    /// @dev 一键生成OEM所有合约
    function createOemContract(
        bytes32 salt,
        InitConfig calldata config
    ) external {
        //总合约保存所有OEM模板合约地址
        //发布OEM工厂合约，OEM多签合约，初始化工厂合约，初始化多签合约
        TemplContractAddr memory _templAddr=templContractAddr;
        require(_templAddr.mltiSigOperator!=address(0),"error");

        address templateFactory = _cloneDeterministic(_templAddr.templateFactory, salt);
        address mltiSigOperator = _cloneDeterministic(_templAddr.mltiSigOperator, salt);
        //初始化数据
        ITemplateFactory(templateFactory).initContract(
            mltiSigOperator,
            _templAddr.mltiSigAgent,
            _templAddr.multiSigColdPro,
            _templAddr.multiSigHotPro,
            _templAddr.multiSigColdStd,
            _templAddr.multiSigColdLite,
            _templAddr.coldContract,
            _templAddr.hotContract,
            _templAddr.merAggregator
        );

        IMultiSigOperator(mltiSigOperator).initManagers(config.ratio,config.expirationTime, config.operatorFeeAddr, _templAddr.mltiSigProtocol, config.managers);
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