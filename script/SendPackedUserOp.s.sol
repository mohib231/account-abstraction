// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MinimalContract} from "../src/ethereum/MinimalContract.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    function run() public {}

    function generateSignedUserOperations(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        MinimalContract minimalContract
    ) public view returns (PackedUserOperation memory) {
        //unsigned data
        uint256 nonce = vm.getNonce(address(minimalContract)) - 1;
        PackedUserOperation memory unsignedUserOperation =
            _generateUnsignedUserOperations(callData, address(minimalContract), nonce);
        //hash data
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(unsignedUserOperation);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        //signed data
        uint8 v;
        bytes32 r;
        bytes32 s;
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(vm.envUint("PRIVATE_KEY"), digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest);
        }

        unsignedUserOperation.signature = abi.encodePacked(r, s, v);

        return unsignedUserOperation;
    }

    function _generateUnsignedUserOperations(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: "",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
