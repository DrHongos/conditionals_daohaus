// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import ""; //ERC1155
// ERC20

// Environment set to test conditional tokens in gnosis chain
// Later create contracts for:
// games, governance, prediction markets, etc

contract ContractTest is Test {

    address CT_gnosis = payable(0xCeAfDD6bc0bEF976fdCd1112955828E00543c0Ce);
    address collateralToken;
    function setUp() public {}

    function testExample() public {
        assertTrue(true);
    }
}
