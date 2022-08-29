// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "forge-std/Script.sol";
import "../src/SimpleDistributor.sol";
import "../src/OpinologoFactory.sol";

contract SimpleDistributorDeployment is Script {
    function setUp() public {}
    address CT_GNOSIS = 0xCeAfDD6bc0bEF976fdCd1112955828E00543c0Ce;
    address currentFactory = 0x4B05b21a6b6F12dEcc260d70F15aF2b4B10B0169;
    function run() public {
        vm.startBroadcast();
//        SimpleDistributor distributor = new SimpleDistributor();
        QuestionsFactory factory = new QuestionsFactory(CT_GNOSIS); // only on factory deployment
//        SimpleDistributorFactory(currentFactory).setTemplate(address(distributor), 0);
        vm.stopBroadcast();
    }
}
