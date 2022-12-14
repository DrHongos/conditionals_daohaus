// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/ICT.sol";
import "../interfaces/User.sol";
import "../src/SimpleDistributor.sol";
import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
/* import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol"; */
import "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

// TODO
// create deep position distributors..

contract SimpleDistributorTest is Test, ERC1155Holder {

    address CT_gnosis = 0xCeAfDD6bc0bEF976fdCd1112955828E00543c0Ce; 
    bytes32 rootCollateral = 0x0000000000000000000000000000000000000000000000000000000000000000; 
    bytes32 questionId1 = 0x0000000000000000000000000000000000000000000000000000000000000001;
    bytes32 questionId2 = 0x0000000000000000000000000000000000000000000000000000000000000002;
    bytes32 questionId3 = 0x0000000000000000000000000000000000000000000000000000000000000003;
    string justification1 = 'AlinkToSomewhere';
    string justification2 =  'Newspapers, Internet, Blogs, Spreadsheets';
    
    mapping(bytes32 => bytes32) conditionsIds;
    uint256 constant PRECISION = 1e18;
    uint initialBalance = 100 * PRECISION;

    address[] public addresses;            // for balance checks
    uint[] public positions;            // subId ERC1155

    uint defaultTimeOut = block.timestamp + 1 days;

    SimpleDistributor distributor;
    User oracle;
    User alice;
    User bob;
    User carol;
    User deedee;
    ERC20PresetMinterPauser collateralToken;

    function setUp() public {
        vm.label(address(this), "Test Contract");
        collateralToken = new ERC20PresetMinterPauser("FakeUSD", "FUSD");
        vm.label(address(collateralToken), "Token Contract");
        oracle = new User(address(collateralToken));
        vm.label(address(oracle), "Oracle");
        alice = new User(address(collateralToken));
        vm.label(address(alice), "Alice");
        bob = new User(address(collateralToken));
        vm.label(address(bob), "Bob");
        carol = new User(address(collateralToken));
        vm.label(address(carol), "Carol");
        deedee = new User(address(collateralToken));
        vm.label(address(deedee), "deedee");
        collateralToken.mint(address(this), initialBalance);        
        distributor = new SimpleDistributor();
/*         collateralToken.mint(address(distributor), initialBalance);         */
    }
    function getCollectionAndPosition(
        address collateral,
        bytes32 parentCollection,
        bytes32 conditionId,
        uint indexSet
    ) public returns (bytes32,uint) {
        bytes32 collection = ICT(CT_gnosis).getCollectionId(
            parentCollection, 
            conditionId, 
            indexSet
        );
        uint positionId = ICT(CT_gnosis).getPositionId(
            collateral, 
            collection
        );
        return (collection, positionId);
    }
    function prepareNewCondition(bytes32 questionId, uint responses) internal returns (bytes32 conditionId) {
        ICT(CT_gnosis).prepareCondition(address(oracle), questionId, responses);
        conditionId = ICT(CT_gnosis).getConditionId(address(oracle), questionId, responses);
        conditionsIds[questionId] = conditionId;
        return conditionId;
        emit log_named_bytes32('Condition created', conditionId);
    }

    function createIncentivizedPrediction(
        bytes32 questionId, 
        uint[] memory indexSets,
        uint timeOut
    ) internal {
/*         collateralToken.approve(CT_gnosis, initialBalance); */
        bytes32 conditionId = prepareNewCondition(questionId1, indexSets.length);
        distributor.initialize(
            conditionId,
            rootCollateral,
            address(collateralToken),
            CT_gnosis,
            indexSets,
            initialBalance,
            timeOut
        );
        emit log_named_address('IO|P created', address(distributor));
    }

    function test_createIncentivizedPrediction() public {
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100       
        collateralToken.transfer(address(distributor), initialBalance);
        createIncentivizedPrediction(questionId1, indexSets, 0);
        assertEq(ICT(CT_gnosis).getOutcomeSlotCount(conditionsIds[questionId1]), 3);
        for (uint i=0; i < 3; i++) {
            (bytes32 condition, uint position) = getCollectionAndPosition(
                address(collateralToken),
                rootCollateral,
                conditionsIds[questionId1],
                indexSets[i]
            );
            assertEq(ICT(CT_gnosis).balanceOf(address(distributor), position), initialBalance);
        }
    }
    function test_userSetDistribution() public {
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100       
        collateralToken.transfer(address(distributor), initialBalance);
        createIncentivizedPrediction(questionId1, indexSets, 0);
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(2);
        alicePrediction[1] = uint(3);
        alicePrediction[2] = uint(5);
        alice.setProbabilityDistribution(address(distributor), alicePrediction, '');
        // *10 comes from a proportion given in the distributor
        assertEq(alicePrediction[0]*10, distributor.probabilityDistribution(address(alice), 0));
        assertEq(alicePrediction[1]*10, distributor.probabilityDistribution(address(alice), 1));    
        assertEq(alicePrediction[2]*10, distributor.probabilityDistribution(address(alice), 2));    
    }
    function testFail_setPredictionClosed() public {
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100       
        collateralToken.transfer(address(distributor), initialBalance);
        createIncentivizedPrediction(questionId1, indexSets, 0);
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(2);
        alicePrediction[1] = uint(3);
        alicePrediction[2] = uint(5);
        distributor.close();
        alice.setProbabilityDistribution(address(distributor), alicePrediction, '');
    }


    function test_updatePrediction() public {
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100       
        collateralToken.transfer(address(distributor), initialBalance);
        createIncentivizedPrediction(questionId1, indexSets, 0);
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(2);
        alicePrediction[1] = uint(3);
        alicePrediction[2] = uint(5);
        alice.setProbabilityDistribution(address(distributor), alicePrediction, '');
        assertEq(alicePrediction[0]*10, distributor.probabilityDistribution(address(alice), 0));
//        assertEq(distributor.probabilityDistribution(address(alice), 0), alicePrediction[0]);
        uint[] memory newPrediction = new uint[](3);
        newPrediction[0] = uint(5);
        newPrediction[1] = uint(3);
        newPrediction[2] = uint(2);
        alice.setProbabilityDistribution(address(distributor), newPrediction, justification1);
        assertEq(distributor.probabilityDistribution(address(alice), 0), newPrediction[0]*10);
        assertEq(distributor.positionsSum(0), newPrediction[0]*10);
        assertEq(distributor.justifiedPositions(address(alice)), justification1);
    }

    function test_addFunds() public {
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100       
        collateralToken.transfer(address(distributor), initialBalance);
        createIncentivizedPrediction(questionId1, indexSets, 0);
        collateralToken.mint(address(this), initialBalance);
        collateralToken.approve(address(distributor), initialBalance);
        distributor.addFunds(initialBalance);
        assertEq(distributor.totalCollateral(), 2*initialBalance);
    }

    function test_timeOut() public {
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100       
        collateralToken.transfer(address(distributor), initialBalance);
        createIncentivizedPrediction(questionId1, indexSets, defaultTimeOut);
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(2);
        alicePrediction[1] = uint(3);
        alicePrediction[2] = uint(5);
        alice.setProbabilityDistribution(address(distributor), alicePrediction, '');
        vm.warp(defaultTimeOut+1);
        vm.expectRevert(bytes("Time is out"));//
        alice.setProbabilityDistribution(address(distributor), alicePrediction, '');
        distributor.changeTimeOut(defaultTimeOut + 1 days);
        alice.setProbabilityDistribution(address(distributor), alicePrediction, '');
        distributor.redemptionTime();
        vm.expectRevert(bytes("Redemption done"));//
        distributor.changeTimeOut(defaultTimeOut + 2 days);        
    }

    function test_complete() public {
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100       
        collateralToken.transfer(address(distributor), initialBalance);
        createIncentivizedPrediction(questionId1, indexSets, 0);
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(2);
        alicePrediction[1] = uint(3);
        alicePrediction[2] = uint(5);
        alice.setProbabilityDistribution(address(distributor), alicePrediction, justification2);

        uint[] memory bobPrediction = new uint[](3);
        bobPrediction[0] = uint(8);
        bobPrediction[1] = uint(8);
        bobPrediction[2] = uint(8);
        bob.setProbabilityDistribution(address(distributor), bobPrediction, justification1);

        uint[] memory payout = new uint[](3);
        payout[0] = 1;
        payout[1] = 0;
        payout[2] = 0;
        oracle.reportPayouts(CT_gnosis, questionId1, payout);
        distributor.redemptionTime();

        alice.redeem(address(distributor));
        bob.redeem(address(distributor));

        alice.redeemPositions(
            CT_gnosis,
            rootCollateral,
            conditionsIds[questionId1],
            indexSets
        );
        bob.redeemPositions(
            CT_gnosis,
            rootCollateral,
            conditionsIds[questionId1],
            indexSets
        );
        assertGt(collateralToken.balanceOf(address(alice)), 0);
        assertGt(collateralToken.balanceOf(address(bob)), 0);
        // check balances
        // it works, but i need to improve the aproximation
/*         uint subTotal = alicePrediction[0]+bobPrediction[0];
        assertEq(collateralToken.balanceOf(address(alice)), initialBalance * alicePrediction[0] / subTotal);
        assertEq(collateralToken.balanceOf(address(bob)), initialBalance * bobPrediction[0] / subTotal); */
    }



}
