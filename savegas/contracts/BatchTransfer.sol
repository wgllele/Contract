// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

contract BatchTransfer{
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    modifier onlyOwner() {
        if (_owner !=msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        _;
    }
    function owner() external view returns (address) {
        return _owner;
    }
    constructor () payable {
        _owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);
    }
    function setOwner(address newOwner) external onlyOwner{
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        emit OwnerChanged(_owner, newOwner);
        _owner = newOwner;
    }
    receive() external payable {
    }

    function multiSend(bytes memory transactions) external onlyOwner payable {
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
}
