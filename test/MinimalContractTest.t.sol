// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {MinimalContract} from "../src/ethereum/MinimalContract.sol";
import {DeployMinimalContract} from "../script/DeployMinimalContract.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol"; // Adjust path if necessary
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {SendPackedUserOp} from "script/SendPackedUserOp.s.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {Vm} from "forge-std/Vm.sol";

contract MinimalContractTest is Test {
    using MessageHashUtils for bytes32;

    HelperConfig helperConfig;
    MinimalContract minimalContract;
    SendPackedUserOp sendPackedUserOp;
    ERC20Mock usdc;
    address randomUser = makeAddr("randomuser");

    function setUp() external {
        DeployMinimalContract deployMinimalContract = new DeployMinimalContract();
        (helperConfig, minimalContract) = deployMinimalContract.run();
        sendPackedUserOp = new SendPackedUserOp();
        // Initialize ERC20Mock
        usdc = new ERC20Mock();
    }

    function test_minimalAccountFunction() public {
        // Assert that the initial balance is zero
        assertEq(usdc.balanceOf(address(minimalContract)), 0);

        address dest = address(usdc);
        uint256 amount = 1e18;

        // Encode the mint function to call it via the minimalContract
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalContract), amount);

        // Prank as the owner to execute the mint function
        vm.prank(minimalContract.owner());
        minimalContract.execute(dest, 0, functionData); // No ETH value needed for minting

        // Assert that the balance of the minimalContract has increased by the minted amount
        assertEq(usdc.balanceOf(address(minimalContract)), amount);
    }

    function test_recoverSignatureOps() public {
        assertEq(usdc.balanceOf(address(minimalContract)), 0);

        address dest = address(usdc);
        uint256 amount = 0;

        // Encode the mint function to call it via the minimalContract
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalContract), amount);
        bytes memory executeData = abi.encodeWithSelector(MinimalContract.execute.selector, dest, amount, functionData);
        PackedUserOperation memory packedOperation =
            sendPackedUserOp.generateSignedUserOperations(executeData, helperConfig.getConfig(), minimalContract);

        bytes32 opHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedOperation);

        address signer = ECDSA.recover(opHash.toEthSignedMessageHash(), packedOperation.signature);
        assert(address(signer) != address(minimalContract));
    }

    function test_validateUserOpSuccess() public {
        assertEq(usdc.balanceOf(address(minimalContract)), 0);
        address dest = address(usdc);
        uint256 amount = 1e18;

        // Encode the mint function to call it via the minimalContract
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalContract), amount);
        bytes memory executeData = abi.encodeWithSelector(MinimalContract.execute.selector, dest, amount, functionData);
        PackedUserOperation memory packedOperation =
            sendPackedUserOp.generateSignedUserOperations(executeData, helperConfig.getConfig(), minimalContract);
        bytes32 opHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedOperation);

        // vm.expectRevert(MinimalContract.MinimalContract__fundsNotEnough);
        vm.prank(address(helperConfig.getConfig().entryPoint));
        uint256 validation = minimalContract.validateUserOp(packedOperation, opHash, amount);
        assertEq(SIG_VALIDATION_SUCCESS, validation);
    }

    function test_validateUserOpFailed() public {
        assertEq(usdc.balanceOf(address(minimalContract)), 0);
        address dest = address(usdc);
        uint256 amount = 0;

        // Encode the mint function to call it via the minimalContract
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalContract), amount);
        bytes memory executeData = abi.encodeWithSelector(MinimalContract.execute.selector, dest, amount, functionData);
        PackedUserOperation memory packedOperation =
            sendPackedUserOp.generateSignedUserOperations(executeData, helperConfig.getConfig(), minimalContract);
        bytes32 opHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedOperation);
        vm.startPrank(address(helperConfig.getConfig().entryPoint));
        vm.expectRevert(MinimalContract.MinimalContract__fundsNotEnough.selector);
        minimalContract.validateUserOp(packedOperation, opHash, amount);
        vm.stopPrank();
    }

    function test_validationOfUserOps() public {
        assertEq(usdc.balanceOf(address(minimalContract)), 0);
        address dest = address(usdc);
        uint256 amount = 1e18;

        // Encode the mint function to call it via the minimalContract
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalContract), amount);
        bytes memory executeData = abi.encodeWithSelector(MinimalContract.execute.selector, dest, amount, functionData);
        PackedUserOperation memory packedOperation =
            sendPackedUserOp.generateSignedUserOperations(executeData, helperConfig.getConfig(), minimalContract);
        // bytes32 opHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedOperation);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedOperation;

        vm.deal(address(minimalContract), 1e18);
        vm.prank(randomUser);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(randomUser));
    }
}
