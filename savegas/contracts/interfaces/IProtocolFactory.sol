// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

struct TemplContractAddr {
   address  mltiSigProtocol;//总合约多签
   address  templateFactory;//OEM工厂合约
   address  mltiSigOperator;//OEM多签合约
   address  mltiSigAgent;
   address  multiSigColdPro;
   address  multiSigHotPro;
   address  multiSigColdStd;
   address  multiSigColdLite;
   address  coldContract;
   address  hotContract;
   address  merAggregator;
}

struct InitConfig {
   uint ratio;//多签通过比例
   uint expirationTime;//签名有效时长
   address operatorFeeAddr;//手续费地址
   address[] managers;//初始化OEM多签管理员（升序排序）
}

interface IProtocolFactory {
   function cloneAccounts(address impl,bytes32[] memory salts) external returns (address[] memory predicteds);
}