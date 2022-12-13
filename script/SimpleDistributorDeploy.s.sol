// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "forge-std/Script.sol";
import "../src/Distributor.sol";
import "../src/OpinologoFactory.sol";

// v0 factory: 0x4B05b21a6b6F12dEcc260d70F15aF2b4B10B0169
// current contract: 0xCD9F95d98EA0C53fc830074AD2f8602468F7F56A

contract SystemDeployment is Script {
    function setUp() public {}
    address CT_GNOSIS = 0xCeAfDD6bc0bEF976fdCd1112955828E00543c0Ce;
//    address prevFactory = 0x3Ff7dD8a9f71c8208397957eDa1001f48D03eB32;
    function run() public {
        vm.startBroadcast();
        Distributor distributor = new Distributor();        
        OpinologosFactory factory = new OpinologosFactory(CT_GNOSIS); // only on factory deployment
        factory.setTemplate(address(distributor), 0);

//        OpinologosFactory(currentFactory).setTemplate(address(distributor), 0);
//        OpinologosFactory(currentFactory).grantRole(CREATOR_ROLE, 0x816a4B059883692F3852E82f343b96B5903b9F03);

        vm.stopBroadcast();
    }
}

/* 
forge script script/SimpleDistributorDeploy.s.sol:SystemDeployment --rpc-url https://rpc.gnosischain.com --private-key XXX --etherscan-api-key XXX --broadcast --verify -vvvv

 */