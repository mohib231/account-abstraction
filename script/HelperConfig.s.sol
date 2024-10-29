// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainid();

    struct NetworkConfig {
        address entryPoint;
        address account;
    }

    NetworkConfig public localNetworkConfig;

    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    uint256 ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 ANVIL_CHAIN_ID = 31337;
    uint256 ZKSYNC_CHAIN_ID = 300;
    address BURNER_WALLET = 0x951519374AEb82f1334163ec2485B65b51Faf217;
    address ANVIL_DEFAULT_WALLET = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() external {}

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainid) public returns (NetworkConfig memory) {
        if (chainid == 31337) {
            return getOrCreateAnvilEthConfig();
        } else if (networkConfigs[chainid].account != address(0)) {
            return networkConfigs[chainid];
        } else {
            revert HelperConfig__InvalidChainid();
        }
    }

    function getEthSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789), account: BURNER_WALLET});
    }

    function getzkSyncSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: address(0), account: BURNER_WALLET});
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }
        // console2.log("Deploying Entry point....");
        vm.startBroadcast(ANVIL_DEFAULT_WALLET);
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();
        localNetworkConfig = NetworkConfig({entryPoint: address(entryPoint), account: ANVIL_DEFAULT_WALLET});
        return localNetworkConfig;
    }
}
