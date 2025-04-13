// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./IMultiSigColdPro.sol";
interface IMultiSigHotPro{
    function initMultiSigCold(IMultiSigColdPro _multiSigCold,uint expirationTime,address[] memory _managers) external;
    function initOwner() external;
}