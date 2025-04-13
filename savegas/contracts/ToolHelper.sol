// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;
import "./interfaces/IERC20Minimal.sol";
import "./interfaces/ISubContract.sol";
import "./interfaces/IMultiSig.sol";
import "./interfaces/ITemplateFactory.sol";
//外围工具合约
contract ToolHelper{
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    constructor() payable{}
    receive() external payable {}
    fallback() external payable {}
    function multiSendAll(bytes memory transactions) external payable {
        assembly {
            let length := mload(transactions)
            let i := 0x20
            for {
            } lt(i, length) {
            } {
                let to := shr(0x60, mload(add(transactions, i)))
                let value := mload(add(transactions, add(i, 0x14)))
                let dataLength := mload(add(transactions, add(i, 0x34)))
                let data := add(transactions, add(i, 0x54))
                let success := call(gas(), to, value, data, dataLength,0, 0)
                if eq(success, 0) {
                    let errorLength := returndatasize()
                    returndatacopy(0, 0, errorLength)
                    revert(0, errorLength)
                }
                i := add(i, add(0x54, dataLength))
            }
        }
    }
    function multiSend(bytes memory transactions) external{
        assembly {
            let length := mload(transactions)
            let i := 0x20
            for {
            } lt(i, length) {
            } {
                let to := shr(0x60, mload(add(transactions, i)))
                let dataLength := mload(add(transactions, add(i, 0x14)))
                let data := add(transactions, add(i, 0x34))
                let success := call(gas(), to, 0, data, dataLength, 0, 0)
                if eq(success, 0) {
                    let errorLength := returndatasize()
                    returndatacopy(0, 0, errorLength)
                    revert(0, errorLength)
                }
                i := add(i, add(0x34, dataLength))
            }
        }
    }
    
    function batchAggregateEths(
        bytes memory transactions
    ) external payable{
        assembly {
            let length := mload(transactions)
            let i := 0x20
            for {
            } lt(i, length) {
            } {
                let account := shr(0x60, mload(add(transactions, i)))
                let data := add(transactions, add(i, 0x14))
                let success := call(gas(), account, 0, data, 0x24, 0, 0)
                if eq(success, 0) {
                    let errorLength := returndatasize()
                    returndatacopy(0, 0, errorLength)
                    revert(0, errorLength)
                }
                i := add(i, 0x38)
            }
        }
    }

    function balances(
        address[] memory _holders,
        address[] memory _tokens
    ) external view returns (bytes memory amounts){
        uint hlength=_holders.length;
        uint tlength=_tokens.length;
        for(uint i;i<hlength;++i){
            for(uint k;k<tlength;k++){
                amounts=abi.encodePacked(amounts,_balance(_tokens[k],_holders[i]));
            }
        }
    }

    function _balance(address _token,address holder) internal view returns (uint256) {
        (bool success, bytes memory data) = _token.staticcall(
            abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, holder)
        );
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }
    function ethBalances(
        address[] memory _holders
    ) external view returns (uint[] memory ammounts){
        uint hlength=_holders.length;
        ammounts=new uint[](hlength);
        for(uint i;i<hlength;++i){
            ammounts[i]=_holders[i].balance;
        }
    }
    
    function computeAddress(bytes32 salt, address impl, address deployer) external view returns (address addr) {
        bytes32 bytecodeHash=impl.codehash;
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40) // Get free memory pointer
            mstore(add(ptr, 0x40), bytecodeHash)
            mstore(add(ptr, 0x20), salt)
            mstore(ptr, deployer) // Right-aligned with 12 preceding garbage bytes
            let start := add(ptr, 0x0b) // The hashed data starts at the final garbage byte which we will set to 0xff
            mstore8(start, 0xff)
            addr := keccak256(start, 85)
        }
    }
    function computeAddress(bytes32 salt, bytes32 bytecodeHash, address deployer) external pure returns (address addr) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40) // Get free memory pointer
            mstore(add(ptr, 0x40), bytecodeHash)
            mstore(add(ptr, 0x20), salt)
            mstore(ptr, deployer) // Right-aligned with 12 preceding garbage bytes
            let start := add(ptr, 0x0b) // The hashed data starts at the final garbage byte which we will set to 0xff
            mstore8(start, 0xff)
            addr := keccak256(start, 85)
        }
    }
    
    function getMessageWithTimestamp(
        bytes32 txHash,
        uint t
    )external pure returns (bytes32 message) {
        message=keccak256(abi.encodePacked(txHash, t));
    }

    function getHashWithTimestamp(
        bytes32 txHash,
        uint t
    )public pure returns (bytes32 digest) {
        bytes32 messageHash=keccak256(abi.encodePacked(txHash, t));
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32") // 32 is the bytes-length of messageHash
            mstore(0x1c, messageHash) // 0x1c (28) is the length of the prefix
            digest := keccak256(0x00, 0x3c) // 0x3c is the length of the prefix (0x1c) + messageHash (0x20)
        }
    }

    function verifySignature(bytes32 messageHash, bytes memory signatures) public pure returns (uint8,bytes32,bytes32,uint t,address) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedMessageHash = keccak256(abi.encodePacked(prefix, messageHash));
        t = signatures.length;
        uint8 v;
        bytes32 r;
        bytes32 s;
        assembly {
                r := mload(add(signatures, 0x20))
                s := mload(add(signatures, 0x40))
                v := byte(0, mload(add(signatures, 0x60)))
            }
        address recoveredAddress = ecrecover(prefixedMessageHash, v, r, s);
          return (v, r ,s,t, recoveredAddress);
    }
    function getSignaturesResult(
        IMultiSig multiSigManager,
        IMultiSig multiSigTrans,
        bytes memory transactions,
        bytes memory signatures
    )external view returns(
       address[] memory owners,
       uint managerNumber,
       uint expirationTime,
       address[] memory managers
    ){
        (managerNumber,expirationTime,managers)=multiSigManager.getManagerInfo();
        address lastOwner = address(0);
        address currentOwner;
        bytes32 dataHash=multiSigTrans.getTransactionHash(transactions);
        owners=new address[](managerNumber);
        for (uint i;i<managerNumber;++i) {
            (uint t,,uint8 v, bytes32 r, bytes32 s) = signatureSplit(signatures, i);
            currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
            owners[i]=currentOwner;
            lastOwner = currentOwner;
        }
    }
    function checkSignaturesResult(
        IMultiSig multiSig,
        bytes memory transactions,
        bytes memory signatures
    )external view returns(
       uint managerNumber,
       uint expirationTime,
       address[] memory managers
    ){
        (managerNumber,expirationTime,managers)=multiSig.getManagerInfo();
        expirationTime= block.timestamp-expirationTime;
        address lastOwner = address(0);
        address currentOwner;
        uint t;
        uint8 j;
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes32 dataHash=multiSig.getTransactionHash(transactions);
        for (uint i;i<managerNumber;++i) {
            (t,j,v, r, s) = signatureSplit(signatures, i);
            require(t > expirationTime ,"expiration error");
            currentOwner = ecrecover(getHashWithTimestamp(dataHash,t), v, r, s);
            require(currentOwner > lastOwner,"manager error");
            require(currentOwner==managers[j],"is not manager");
            lastOwner = currentOwner;
        }
    }
    function signatureSplit(
        bytes memory signatures, 
        uint256 pos
    ) public pure returns (
        uint t,
        uint8 j,
        uint8 v, 
        bytes32 r, 
        bytes32 s
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
    function getAddManager(
        address[] memory managers,
        address _target,
        uint256 _index
    ) external virtual view returns(address[] memory _managers){
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
        _managers=new address[](length+1);
        for(uint i=0;i<length;++i){
            _managers[i]=managers[i];
        }
        for(uint i=length;i>_index;--i){
            _managers[i]=_managers[i-1];
        }
        _managers[_index]=_target;
    }
    function getRmManagerResult(
        address[] memory _managers,
        uint256 _index
    ) external virtual view returns (address[] memory managers){
        managers=_managers;
        uint length=managers.length;
        require(length > 2 , "Manager cannot be less than two");
        require(_index<length, "address is not exist");
        for (uint i=_index; i < length; ++i) {
            managers[i]=managers[i+1];
        }
    }
    function getBytecodeAndHash(
        address impl
    ) external view returns(
        bytes memory bytecode,
        bytes32 bytecodeHash
    ){
        bytecode=impl.code;
        bytecodeHash=impl.codehash;
    }
    function isContract(address account) public view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
    
    function getSendErc20Transactions(
        address[] memory tokens,
        address[] memory tos,
        uint[] memory amounts
    ) external pure returns (bytes memory transactions){
        uint length=tokens.length;
        for(uint i;i<length;++i){
            transactions=abi.encodePacked(transactions,
                tokens[i],
                abi.encodeWithSelector(0xa9059cbb, tos[i],amounts[i])
            );
        }
    }
    function getSendEthTransactions(
        address[] memory tos,
        uint[] memory amounts
    ) external pure returns (bytes memory transactions){
        uint length=tos.length;
        for(uint i;i<length;++i){
            transactions=abi.encodePacked(transactions,
                tos[i],
                amounts[i]
            );
        }
    }
    function getAccountsSendErc20sTransactions(
        address[] memory accounts,
        address[] memory tos,
        uint minAmount,
        address[] memory tokens
    ) external view returns (bytes memory transactions){
        for(uint i;i<accounts.length;++i){
            transactions=abi.encodePacked(transactions,getAccountSendErc20sTransactions(
                accounts[i],tos[i],minAmount,tokens
            ));
        }
    }
    function getAccountSendErc20sTransactions(
        address account,
        address to,
        uint minAmount,
        address[] memory tokens
    ) public view returns (bytes memory transactions){
         uint length=tokens.length;
        for(uint i;i<length;++i){
            uint amount=_balance(tokens[i],account);
            if(amount>=minAmount){
                transactions=abi.encodePacked(transactions,
                    tokens[i],
                    abi.encodeWithSelector(0xa9059cbb, to,amount)
                );
            }
        }
        bytes memory data=abi.encodeWithSelector(ISubContract.sendErc20s.selector, transactions);
        transactions=abi.encodePacked(account,data.length,data);
    }
    function getAccountsSendEthTransactions(
        uint minAmount,
        address[] memory accounts
    ) external view returns (bytes memory transactions){
        for(uint i;i<accounts.length;++i){
            uint amount=accounts[i].balance;
            if(amount>=minAmount){
                bytes memory data=abi.encodeWithSelector(ISubContract.sendEth.selector, amount);
                transactions=abi.encodePacked(transactions,accounts[i],data.length,data);
            }
        }
    }
    function getAccountsExist(
        address[] memory accounts
    ) external view returns (bool[] memory exists){
        uint length= accounts.length;
        exists=new bool[](length);
        for(uint i;i<length;++i){
            exists[i]=isContract(accounts[i]);
        }
    }

    function getBalances(address[] memory addr, address erc20) external view returns (bool[] memory bal){
        uint length = addr.length;
        bal=new bool[](length);
        if(erc20 == address(0)) {
            for(uint i;i<length;++i){
                bal[i] = addr[i].balance > 0;
            }
        } else {
            for(uint i;i<length;++i){
                bal[i] = IERC20Minimal(erc20).balanceOf(addr[i])>0;
            }
        }
    }

    function getBalance(address addr, address erc20) external view returns (uint256){
        uint256 bal = 0;
        if(erc20 == address(0)) {
            bal = addr.balance;
        } else {
            bal = IERC20Minimal(erc20).balanceOf(addr);
        }
        return bal;
    }
    function predictAccounts(
        address impl,
        bytes32[] memory salts,
        address deployer
    ) external pure returns (address[] memory predicteds) {
        uint length=salts.length;
        predicteds=new address[](length);
        for(uint i;i<length;++i){
            predicteds[i]=predictAccount(impl,salts[i],deployer);
        }
    }
    function predictAccount(
        address impl,
        bytes32 salt,
        address deployer
    ) public pure returns (address predicted) {
        assembly {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x38), deployer)
            mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff)
            mstore(add(ptr, 0x14), impl)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
            mstore(add(ptr, 0x58), salt)
            mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37))
            predicted := keccak256(add(ptr, 0x43), 0x55)
        }
    }
    function getCloneAccountsTransactions(
        address impl,
        bytes32[] memory salts,
        address agentFactory
    ) external pure returns (bytes memory transactions){
        bytes memory data=abi.encodeWithSelector(ITemplateFactory.cloneAccounts.selector, impl,salts);
        transactions=abi.encodePacked(agentFactory,data.length,data);
    }
    function getPackedTransactions(
        bytes[] memory transactionDatas
    ) external pure returns (bytes memory transactions){
        uint length= transactionDatas.length;
        for(uint i;i<length;++i){
            transactions=abi.encodePacked(transactions,transactionDatas[i]);
        }
    }
}