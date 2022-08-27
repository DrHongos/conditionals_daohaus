// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "forge-std/Script.sol";
import "../src/SimpleDistributor.sol";
import "../src/SimpleDistributorFactory.sol";

contract SimpleDistributorDeployment is Script {
    function setUp() public {}
    address currentFactory = 0x4B05b21a6b6F12dEcc260d70F15aF2b4B10B0169;
    function run() public {
        vm.startBroadcast();
        SimpleDistributor distributor = new SimpleDistributor();
        //SimpleDistributorFactory factory = new SimpleDistributorFactory(address(distributor));
        SimpleDistributorFactory(currentFactory).changeTemplate(address(distributor));
        vm.stopBroadcast();
    }
}
