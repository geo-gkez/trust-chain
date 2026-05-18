// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {TrustChain} from "../src/TrustChain.sol";

/// @notice Minimal Sepolia deployment — one deployer becomes Admin.
///         No demo seeding. Register real users via the UI after deployment.
///
/// Prerequisites:
///   1. Copy contracts/.env.example to contracts/.env and fill in your values
///   2. Fund the deployer wallet with ~0.05 Sepolia ETH
///
/// Usage (from the contracts/ directory):
///   source .env
///   forge script script/DeploySepoliaMinimal.s.sol \
///     --rpc-url $SEPOLIA_RPC \
///     --private-key $PRIVATE_KEY \
///     --broadcast --verify -vvvv
contract DeploySepoliaMinimal is Script {
    function run() external returns (TrustChain) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);
        TrustChain tc = new TrustChain();
        vm.stopBroadcast();

        console.log("TrustChain deployed at:", address(tc));
        console.log("Admin (deployer):", vm.addr(deployerKey));
        console.log("");
        console.log("Next: update ui/.env with these Sepolia values:");
        console.log("  VITE_CONTRACT_ADDRESS=", address(tc));
        console.log("  VITE_CHAIN_ID=0xaa36a7");
        console.log("  VITE_CHAIN_NAME=Sepolia");
        console.log("  VITE_RPC_URL=<your-rpc-url>");

        return tc;
    }
}
