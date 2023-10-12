// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "../lib/forge-std/src/Script.sol";
import "../src/Distributor.sol";
import "../src/DistributorFactory.sol";
import "../src/OpinologoFactory.sol";

contract SystemDeployment is Script {
    function setUp() public {}
    address CT_GNOSIS = 0xCeAfDD6bc0bEF976fdCd1112955828E00543c0Ce;
//    address currentFactory = 0x9Db139a6f06de84C19C26BAE3EFa68985AA0852F;
    function run() public {
        vm.startBroadcast();
        OpinologosFactory opinologos = new OpinologosFactory(CT_GNOSIS); // only on factory deployment
        Distributor distributor = new Distributor();        
        DistributorFactory distributorFactory = new DistributorFactory(CT_GNOSIS, address(opinologos));
        distributorFactory.setTemplate(address(distributor));

        //opinologos.grantRole(CREATOR_ROLE, 0x816a4B059883692F3852E82f343b96B5903b9F03);
        vm.stopBroadcast();
    }
}

/* 
forge script script/SimpleDistributorDeploy.s.sol:SystemDeployment --rpc-url https://rpc.gnosischain.com --private-key XXX --etherscan-api-key XXX --broadcast --verify -vvvv

 */