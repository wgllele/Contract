// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;
abstract contract ReentrancyGuardTransient {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;
    error ReentrancyGuardTransientReentrantCall();
    constructor() {
        _status = NOT_ENTERED;
    }
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }
    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardTransientReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }
    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    function _ReentrancyGuardTransientEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}