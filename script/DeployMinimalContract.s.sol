// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MinimalContract} from "../src/ethereum/MinimalContract.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMinimalContract is Script {
    function run() external returns (HelperConfig helperConfig, MinimalContract minimalContract) {
        (helperConfig, minimalContract) = deployMinimalContract();
    }

    function deployMinimalContract() internal returns (HelperConfig, MinimalContract) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        MinimalContract minimalContract = new MinimalContract(config.entryPoint);
        minimalContract.transferOwnership(minimalContract.owner());
        vm.stopBroadcast();

        return (helperConfig, minimalContract);
    }
}
