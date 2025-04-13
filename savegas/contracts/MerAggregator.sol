// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./interfaces/IMerAggregator.sol";
import "./interfaces/IERC20Minimal.sol";
import "./interfaces/ISubContract.sol";
//汇总账户子合约的辅助合约
contract MerAggregator is IMerAggregator{
    address private _owner;
    error OwnableUnauthorizedAccount(address account);
    error UnableToTransferFromTokenToAddress(address token, address from, address recipient, uint256 amount);
    constructor() {
    }
    modifier onlyOwner() {
        if (_owner!=msg.sender) {
            //管理员只要有效，就校验管理员权限
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        _;
    }
    function owner() public view returns (address) {
        return _owner;
    }
    //为了首次初始化操作使用，如果等于10代表已经初始化过
    uint public status;
    //汇总到的目标冷合约地址
    address payable public coldPool;
    //需要汇总的erc20代币信息
    address[] private supportTokens;
    function initConfig(address[] memory _tokens,address payable _coldPool,address _multiSigCold) external{
        require(status!=1,"only init once");
        status=1;
        _setTokens(_tokens);
        coldPool=_coldPool;
        _owner=_multiSigCold;
    }
    //重新设置汇总ERC20代币地址信息
    function _setTokens(address[] memory _tokens) internal{
        uint len=_tokens.length;
        uint slen=supportTokens.length;
        while(slen>len){
            supportTokens.pop();
            slen--;
        }
        if(len>slen){
            for(uint i;i<slen;++i){
                supportTokens[i]=_tokens[i];
            }
            for(uint i=slen;i<len;++i){
                supportTokens.push(_tokens[i]);
            }
        }else{
            for(uint i;i<slen;++i){
                supportTokens[i]=_tokens[i];
            }
        }
    }
    function setTokens(address[] memory _tokens) external onlyOwner{
        _setTokens(_tokens);
    }
    //查询erc20代币余额，该方法不会因为查询错误而中断其他逻辑的运行
    function _balance(address _token,address holder) internal view returns (uint112 tokenBal) {
        assembly {
            let emptyPointer := mload(0x40)
            mstore(emptyPointer, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(emptyPointer, 0x04), holder)
            let success := staticcall(gas(), _token, emptyPointer, 0x24, emptyPointer, 0x40)
            if success {
                tokenBal := mload(emptyPointer)
            }
        }
    }
    //汇总账户子合约资金，必须通过账户子合约来调用
    function aggregateAsset() external payable{
        bytes memory transactions;
        address _coldPool=coldPool;
        address holder=msg.sender;
        //计算出erc20代币种类数，token的长度20位(0x14)
        address[] memory tokens=supportTokens;
        uint slen=tokens.length;
        for(uint i;i<slen;++i){
            if(tokens[i]!=address(0)){
                uint amount=_balance(tokens[i],holder);
                //余额大于0才能汇总
                if(amount>0){
                    transactions=abi.encodePacked(transactions,
                        tokens[i],
                        abi.encodeWithSelector(0xa9059cbb,_coldPool,amount)
                    );
                }
            }else{//token位零地址代表汇总eth主链币本身
                uint amount=holder.balance;
                if(amount>0){
                    ISubContract(holder).sendEth(amount);
                }
            }
        }
        if (transactions.length > 0) {
            //批量汇总账户资产
            ISubContract(holder).sendErc20s(transactions);
        }
    }
    function tokenTransferFrom(address _token, address from, address recipient, uint256 amount) internal {
        bool failed = false;
        assembly {
            let emptyPointer := mload(0x40)
            mstore(emptyPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(emptyPointer, 0x04), from)
            mstore(add(emptyPointer, 0x24), recipient)
            mstore(add(emptyPointer, 0x44), amount)
            failed := iszero(call(gas(), _token, 0, emptyPointer, 0x64, 0, 0))
        }
        if (failed) revert UnableToTransferFromTokenToAddress(from,_token,recipient,amount);
    }
    //直接支付主链币eth到冷合约里面，并记录订单数据到日志
    function orderPaymentEth(uint256 orderId) external payable  returns(bool sucess){
        require(msg.value > 0, "Amount must be greater than 0");
        require(coldPool != address(0));
        (sucess,) = coldPool.call{value: msg.value}("");
        require(sucess, "Transfer to cold pool failed.");
        emit PaymentReceived(msg.sender, address(0), msg.value, orderId);
    }
    //直接支付erc20代币到冷合约，并记录订单数据到日志
    function orderPayment(address token, uint256 amount, uint256 orderId ) external {
        require(amount>0, "amount must be greater than 0");
        require(coldPool != address(0));
        tokenTransferFrom(token,msg.sender, coldPool, amount);
        emit PaymentReceived(msg.sender, token, amount, orderId);
    }
}