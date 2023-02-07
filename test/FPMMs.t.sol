// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../interfaces/ICT.sol";

import "../interfaces/IFixedProductMarketMaker.sol";
import "../interfaces/IFPMMDeterministicFactory.sol";

import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
// ERC20

// Environment set to test conditional tokens in gnosis chain
// forge test --fork-url https://rpc.gnosischain.com
// Later create contracts for:
// games, governance, prediction markets, etc

contract FPMMsTest is Test, ERC1155Holder {

    address CT_gnosis = 0xCeAfDD6bc0bEF976fdCd1112955828E00543c0Ce;
    address FPMMFactory_gnosis = 0x9083A2B699c0a4AD06F63580BDE2635d26a3eeF0;

    bytes32 rootCollateral = 0x0000000000000000000000000000000000000000000000000000000000000000; 
    bytes32 questionId1 = 0x0000000000000000000000000000000000000000000000000000000000000001;
    bytes32 questionId2 = 0x0000000000000000000000000000000000000000000000000000000000000002;
    bytes32 questionId3 = 0x0000000000000000000000000000000000000000000000000000000000000003;

    mapping(bytes32 => bytes32) conditionsIds;

    uint256 constant PRECISION = 1e18;
    uint initialBalance = 100 * PRECISION;
    address oracle = address(0);
    address alice = address(1);
    address bob = address(2);
    address carol = address(3);
    address deedee = address(4);
    ERC20PresetMinterPauser collateralToken;
    IFPMMDeterministicFactory marketFactory;
    ICT pmSystem;

    mapping(uint => bytes32) collectionsIds;
/*     mapping(uint => uint256) positionsIds; */


    function setUp() public {
        vm.label(address(this), "Test Contract");
        collateralToken = new ERC20PresetMinterPauser("FakeUSD", "FUSD");
        vm.label(address(collateralToken), "Token Contract");
        vm.label(oracle, "Oracle");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(carol, "Carol");
        vm.label(deedee, "deedee");
        marketFactory = IFPMMDeterministicFactory(FPMMFactory_gnosis); 
        pmSystem = ICT(CT_gnosis);
        collateralToken.mint(address(this), initialBalance);        
        collateralToken.mint(alice, initialBalance);
        collateralToken.mint(bob, initialBalance);
        collateralToken.mint(carol, initialBalance);
        collateralToken.mint(deedee, initialBalance);
    }

    function prepareNewCondition(bytes32 questionId, uint responses) internal {
        ICT(CT_gnosis).prepareCondition(oracle, questionId, responses);
        bytes32 conditionId = ICT(CT_gnosis).getConditionId(oracle, questionId, responses);
        conditionsIds[questionId] = conditionId;
        emit log_named_bytes32('Condition created', conditionId);
    }
    // create function to check all indexSets, maybe get total balancesº of a conditionId

    function test_prepareCondition() public {
        prepareNewCondition(questionId1, 2);
        assertEq(ICT(CT_gnosis).getOutcomeSlotCount(conditionsIds[questionId1]), 2);
    }
    function test_createMarket() public {
        uint responses = 2;
        prepareNewCondition(questionId1, responses);
        bytes32 conditionId = ICT(CT_gnosis).getConditionId(oracle, questionId1, responses);
        bytes32[] memory conditions = new bytes32[](1);
        conditions[0] = conditionId;
        uint[] memory distributionHint = new uint[](responses);
        for (uint i = 0; i < responses; i++) {
            distributionHint[i] = uint(1);
        }
        uint initial_liquidity = 10 * PRECISION;
        vm.startPrank(alice);
        collateralToken.approve(address(marketFactory), initial_liquidity);
        IFixedProductMarketMaker market_address = marketFactory.create2FixedProductMarketMaker(
            uint(69),//uint saltNonce,
            pmSystem,//ICT conditionalTokens,
            collateralToken,//IERC20 collateralToken,
            conditions,//bytes32[] calldata conditionIds,
            0,//uint fee,
            initial_liquidity,//uint initialFunds,
            distributionHint//uint[] calldata distributionHint
        );
        vm.stopPrank();        
        IFixedProductMarketMaker market = IFixedProductMarketMaker(market_address);
    }

    function test_testMarket() public {
        uint responses = 3;
        prepareNewCondition(questionId1, responses);
        bytes32 conditionId = ICT(CT_gnosis).getConditionId(oracle, questionId1, responses);
        bytes32[] memory conditions = new bytes32[](1);
        conditions[0] = conditionId;
        uint[] memory distributionHint = new uint[](responses);
        for (uint i = 0; i < responses; i++) {
            distributionHint[i] = uint(1);
        }
        uint initial_liquidity = 10 * PRECISION;
        vm.startPrank(alice);
        collateralToken.approve(address(marketFactory), initial_liquidity);
        IFixedProductMarketMaker market_address = marketFactory.create2FixedProductMarketMaker(
            uint(69),//uint saltNonce,
            pmSystem,//ICT conditionalTokens,
            collateralToken,//IERC20 collateralToken,
            conditions,//bytes32[] calldata conditionIds,
            0,//uint fee,
            initial_liquidity,//uint initialFunds,
            distributionHint//uint[] calldata distributionHint
        );
        vm.stopPrank();        
        IFixedProductMarketMaker market = IFixedProductMarketMaker(market_address);

        // bob buys a bet
        vm.startPrank(bob);
        uint bob_bet = 1 * PRECISION;
        uint bob_outcome = uint(0);
        collateralToken.approve(address(market), bob_bet);
        uint bob_amount = market.calcBuyAmount(bob_bet, bob_outcome);
        market.buy(bob_bet, bob_outcome, bob_amount);
        vm.stopPrank();

        // Carol too
        vm.startPrank(carol);
        uint carol_bet = 1 * PRECISION;
        uint carol_outcome = uint(1);
        collateralToken.approve(address(market), carol_bet);
        uint carol_amount = market.calcBuyAmount(carol_bet, carol_outcome);
        market.buy(carol_bet, carol_outcome, carol_amount);
        vm.stopPrank();

        // and Alice
        vm.startPrank(alice);
        uint alice_bet = 1 * PRECISION;
        uint alice_outcome = uint(2);
        collateralToken.approve(address(market), alice_bet);
        uint alice_amount = market.calcBuyAmount(alice_bet, alice_outcome);
        market.buy(alice_bet, alice_outcome, alice_amount);
        vm.stopPrank();


    }

    function test_redeemGains() public {
        uint responses = 2;
        prepareNewCondition(questionId1, responses);
        bytes32 conditionId = ICT(CT_gnosis).getConditionId(oracle, questionId1, responses);
        bytes32[] memory conditions = new bytes32[](1);
        conditions[0] = conditionId;
        uint[] memory distributionHint = new uint[](responses);
        for (uint i = 0; i < responses; i++) {
            distributionHint[i] = uint(1);
        }
        uint initial_liquidity = 10 * PRECISION;
        vm.startPrank(alice);
        collateralToken.approve(address(marketFactory), initial_liquidity);
        IFixedProductMarketMaker market_address = marketFactory.create2FixedProductMarketMaker(
            uint(69),//uint saltNonce,
            pmSystem,//ICT conditionalTokens,
            collateralToken,//IERC20 collateralToken,
            conditions,//bytes32[] calldata conditionIds,
            0,//uint fee,
            initial_liquidity,//uint initialFunds,
            distributionHint//uint[] calldata distributionHint
        );
        vm.stopPrank();        
        IFixedProductMarketMaker market = IFixedProductMarketMaker(market_address);

        // bob buys a bet
        vm.startPrank(bob);
        uint bob_bet = 1 * PRECISION;
        uint bob_outcome = uint(0);
        collateralToken.approve(address(market), bob_bet);
        uint bob_amount = market.calcBuyAmount(bob_bet, bob_outcome);
        market.buy(bob_bet, bob_outcome, bob_amount);
        vm.stopPrank();

        // Carol too
        vm.startPrank(carol);
        uint carol_bet = 1 * PRECISION;
        uint carol_outcome = uint(1);
        collateralToken.approve(address(market), carol_bet);
        uint carol_amount = market.calcBuyAmount(carol_bet, carol_outcome);
        market.buy(carol_bet, carol_outcome, carol_amount);
        vm.stopPrank();

        uint[] memory dummy_array = new uint[](2);
        dummy_array[0] = 1;
        dummy_array[1] = 0;

        // answer the question
        vm.prank(oracle);
        ICT(CT_gnosis).reportPayouts(questionId1, dummy_array);
        dummy_array[0] = 1;
        dummy_array[1] = 2;

        // remove funding
        vm.startPrank(alice);
        market.removeFunding(initial_liquidity);
        ICT(CT_gnosis).redeemPositions(collateralToken, rootCollateral, conditionId, dummy_array);
        collateralToken.balanceOf(alice);
        vm.stopPrank();


        vm.startPrank(bob);
        ICT(CT_gnosis).redeemPositions(collateralToken, rootCollateral, conditionId, dummy_array);
        collateralToken.balanceOf(bob);
        vm.stopPrank();
        vm.startPrank(carol);
        ICT(CT_gnosis).redeemPositions(collateralToken, rootCollateral, conditionId, dummy_array);
        collateralToken.balanceOf(carol);
        vm.stopPrank();
    }

    function test_deepMarkets() public {
        uint responses = 2;
        uint responses2 = 3;
        prepareNewCondition(questionId1, responses);
        prepareNewCondition(questionId2, responses2);
//        bytes32 conditionId = ICT(CT_gnosis).getConditionId(oracle, questionId1, responses);
        bytes32[] memory conditions = new bytes32[](2);
        conditions[0] = conditionsIds[questionId1];
        conditions[1] = conditionsIds[questionId2];
        uint atomicOutcomesTotal = responses2 * responses;
        uint[] memory distributionHint = new uint[](atomicOutcomesTotal);
        for (uint i = 0; i < atomicOutcomesTotal; i++) {
            distributionHint[i] = uint(1);
        }
        uint initial_liquidity = 10 * PRECISION;
        vm.startPrank(alice);
        collateralToken.approve(address(marketFactory), initial_liquidity);
        IFixedProductMarketMaker market_address = marketFactory.create2FixedProductMarketMaker(
            uint(69),//uint saltNonce,
            pmSystem,//ICT conditionalTokens,
            collateralToken,//IERC20 collateralToken,
            conditions,//bytes32[] calldata conditionIds,
            0,//uint fee,
            initial_liquidity,//uint initialFunds,
            distributionHint//uint[] calldata distributionHint
        );
        vm.stopPrank();        
        IFixedProductMarketMaker market = IFixedProductMarketMaker(market_address);

/* 
            check how the outcome is related to the mixed conditions
            i think is:
                Q1        Q2
            [Hi, Lo], [A, B, C] =>
            Hi && A = 0
            Hi && B = 1
            Hi && C = 2
            Lo && A = 3
            Lo && B = 4
            Lo && C = 5

 */

        // bob buys a bet
        vm.startPrank(bob);
        uint bob_bet = 1 * PRECISION;
        uint bob_outcome = uint(0);
        collateralToken.approve(address(market), bob_bet);
        uint bob_amount = market.calcBuyAmount(bob_bet, bob_outcome);
        market.buy(bob_bet, bob_outcome, bob_amount);
        vm.stopPrank();

        // Carol too
        vm.startPrank(carol);
        uint carol_bet = 1 * PRECISION;
        uint carol_outcome = uint(1);
        collateralToken.approve(address(market), carol_bet);
        uint carol_amount = market.calcBuyAmount(carol_bet, carol_outcome);
        market.buy(carol_bet, carol_outcome, carol_amount);
        vm.stopPrank();

        uint[] memory dummy_array = new uint[](responses);
        dummy_array[0] = 1;
        dummy_array[1] = 0;

        // answer the question
        vm.prank(oracle);
        ICT(CT_gnosis).reportPayouts(questionId1, dummy_array);

        uint[] memory dummy_array_2 = new uint[](responses2);
        dummy_array_2[0] = 1;
        dummy_array_2[1] = 0;
        dummy_array_2[2] = 0;
        vm.prank(oracle);
        ICT(CT_gnosis).reportPayouts(questionId2, dummy_array_2);

        dummy_array[0] = 1;
        dummy_array[1] = 2;
        dummy_array_2[0] = 1;
        dummy_array_2[1] = 2;
        dummy_array_2[2] = 4;

        // remove funding
        // get winner collection to retrieve
        bytes32 collectionWinner = ICT(CT_gnosis).getCollectionId(
            rootCollateral,                 // from collateral
            conditionsIds[questionId1],     // Q1
            1                               // winning position
        );
        vm.startPrank(alice);
        market.removeFunding(initial_liquidity);
        ICT(CT_gnosis).redeemPositions(collateralToken, collectionWinner, conditionsIds[questionId2], dummy_array_2);
        ICT(CT_gnosis).redeemPositions(collateralToken, rootCollateral, conditionsIds[questionId1], dummy_array);
        collateralToken.balanceOf(alice);
        vm.stopPrank();


        vm.startPrank(bob);
        ICT(CT_gnosis).redeemPositions(collateralToken, collectionWinner, conditionsIds[questionId2], dummy_array_2);
        ICT(CT_gnosis).redeemPositions(collateralToken, rootCollateral, conditionsIds[questionId1], dummy_array);
        collateralToken.balanceOf(bob);
        vm.stopPrank();
        vm.startPrank(carol);
        ICT(CT_gnosis).redeemPositions(collateralToken, collectionWinner, conditionsIds[questionId2], dummy_array_2);
        ICT(CT_gnosis).redeemPositions(collateralToken, rootCollateral, conditionsIds[questionId1], dummy_array);
        collateralToken.balanceOf(carol);
        vm.stopPrank();
    }

    function test_deeperMarkets() public {

    }

}
