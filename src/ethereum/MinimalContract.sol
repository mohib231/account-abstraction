// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract MinimalContract is IAccount, Ownable {
    error MinimalContract__fundsNotEnough();
    error MinimalContract__NotFromEntryPoint();
    error MinimalAccount__CallFailed(bytes);
    error MinimalContract__NotFromEntryPointOrOwner();

    IEntryPoint immutable i_entryPoint;

    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {}

    modifier requireFromEntryPoint() {
        if (i_entryPoint != IEntryPoint(msg.sender)) {
            revert MinimalContract__NotFromEntryPoint();
        }
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalContract__NotFromEntryPointOrOwner();
        }
        _;
    }

    function execute(address dest, uint256 amount, bytes calldata functionData) external requireFromEntryPointOrOwner {
        (bool success, bytes memory result) = dest.call{value: amount}(functionData);
        if (!success) {
            revert MinimalAccount__CallFailed(result);
        }
    }

    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }

    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);

        if (signer != owner()) return SIG_VALIDATION_FAILED;

        return SIG_VALIDATION_SUCCESS;
    }

    function _payPrefund(uint256 missingAccountFunds) internal returns (bool) {
        if (missingAccountFunds == 0) {
            revert MinimalContract__fundsNotEnough();
        }
        (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
        return success;
    }

    function getEntryPoint() public view returns (IEntryPoint) {
        return i_entryPoint;
    }
}
