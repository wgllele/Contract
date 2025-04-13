// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

struct TemplAddr {
   address  mltiSigOperator;
   address  mltiSigAgent;
   address  multiSigColdPro;
   address  multiSigHotPro;
   address  multiSigColdStd;
   address  multiSigColdLite;
   address  coldContract;
   address  hotContract;
   address  merAggregator;
}

struct MerInitConfig {
   bytes accountCode;//子合约字节码
   uint index;//提交管理员下标
   uint coldRatio;//冷合约多签通过比例
   uint expirationTime;//签名有效时长
   address[] coldManagers;//初始化冷合约多签管理员（大小顺序排序）
   address[] hotManagers;//初始热合约多签管理员,（大小顺序排序）
   address[] tokens; //商户支持币种（eth填写0x00那个地址）
}


struct OrgConfig {
    uint256 org_id;
    uint org_type;//类型
    uint256 org_parent_id;
    bytes32 salt;
    bool is_setup;
}

interface ITemplateFactory {
   function cloneAccounts(address impl,bytes32[] memory salts) external returns (address[] memory predicteds);
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
    ) external;
}