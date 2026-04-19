// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {TrustChain} from "../src/TrustChain.sol";

/// @notice Deploys TrustChain to Anvil (or any EVM chain).
///         Run with:
///           forge script script/Deploy.s.sol \
///             --rpc-url http://localhost:8545 \
///             --broadcast \
///             --private-key <ANVIL_PRIVATE_KEY>
contract Deploy is Script {
    function run() external returns (TrustChain tc) {
        vm.startBroadcast();
        tc = new TrustChain();
        vm.stopBroadcast();

        console.log("TrustChain deployed at:", address(tc));
    }
}
