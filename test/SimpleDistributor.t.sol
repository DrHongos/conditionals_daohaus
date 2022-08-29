// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/ICT.sol";
import "../interfaces/User.sol";
import "../src/SimpleDistributor.sol";
import "../src/OpinologoFactory.sol";
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
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    
    mapping(bytes32 => bytes32) conditionsIds;
    uint256 constant PRECISION = 1e18;
    uint initialBalance = 100 * PRECISION;

    address[] public addresses;            // for balance checks
    uint[] public positions;            // subId ERC1155

    uint defaultTimeOut = block.timestamp + 1 days;

    QuestionsFactory factory;
    SimpleDistributor distributor_template;
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
        collateralToken.mint(address(alice), initialBalance);        
        distributor_template = new SimpleDistributor();
        factory = new QuestionsFactory(CT_gnosis);
        vm.label(address(factory), "Factory");
        factory.setTemplate(address(distributor_template), 0);        
        factory.grantRole(CREATOR_ROLE, address(this));
        bytes32 condition_created = factory.createQuestion(address(oracle), questionId1, 3);
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100
        alice.createDistributor(
            address(factory),
            rootCollateral,
            address(collateralToken),
            indexSets,
            0, // template index
            0  // question index
        );                 
        address distributor_address = factory.getDistributorAddress(0);
        vm.label(distributor_address, "Distributor");        
    }
///////////////////////////////////////////////// HELPERS
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
///////////////////////////////////////////////// TESTS

    function test_createIncentivizedPrediction() public {
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100
        uint initial_amount = 10000;
        address distributor = factory.getDistributorAddress(0);
        alice.approveCollateral(distributor, initial_amount);
        alice.configure(
            factory.getDistributorAddress(0),
            initial_amount, //amountToSplit
            0, //timeOut (no limit)
            0, //price
            0 //fee
        );
        assertEq(ICT(CT_gnosis).getOutcomeSlotCount(factory.getCondition(0)), 3);
        
        for (uint i=0; i < 3; i++) {
            (bytes32 condition, uint position) = getCollectionAndPosition(
                address(collateralToken),
                factory.getParentCollection(0),
                factory.getCondition(0),
                indexSets[i]
            );
        assertEq(ICT(CT_gnosis).balanceOf(address(distributor), position), initial_amount);
        }
    }

     function test_userSetDistribution() public {
        uint initial_amount = 10000;
        address distributor = factory.getDistributorAddress(0);
        alice.approveCollateral(distributor, initial_amount);
        alice.configure(
            factory.getDistributorAddress(0),
            initial_amount, //amountToSplit
            0, //timeOut (no limit)
            0, //price
            0 //fee
        );
        uint[] memory bobPrediction = new uint[](3);
        bobPrediction[0] = uint(2);
        bobPrediction[1] = uint(3);
        bobPrediction[2] = uint(5);
        bob.setProbabilityDistribution(address(distributor), bobPrediction, 'A long string to test storage issues');
        // *10 comes from a proportion given in the distributor
        assertTrue(ISimpleDistributor(distributor).userSet(address(bob)));
/*      reverts the call to get the prediction of an address..idk
         uint[] memory bobStoredPrediction = ISimpleDistributor(distributor).probabilityDistribution(address(bob));
        assertEq(bobPrediction[0]*10, bobStoredPrediction[0]);
        assertEq(bobPrediction[1]*10, bobStoredPrediction[1]);    
        assertEq(bobPrediction[2]*10, bobStoredPrediction[2]);     */
    }


     function testFail_setPredictionClosed() public {
        uint initial_amount = 10000;
        address distributor = factory.getDistributorAddress(0);
        alice.approveCollateral(distributor, initial_amount);
        alice.configure(
            factory.getDistributorAddress(0),
            initial_amount, //amountToSplit
            0, //timeOut (no limit)
            0, //price
            0 //fee
        );
        alice.closeDistributor(distributor);
        uint[] memory bobPrediction = new uint[](3);
        bobPrediction[0] = uint(2);
        bobPrediction[1] = uint(3);
        bobPrediction[2] = uint(5);
        bob.setProbabilityDistribution(address(distributor), bobPrediction, 'A long string to test storage issues');
    }

//////////////////////////////////////////////////////////////////////////////////////        
//
//          Below tests need to be adapted to new version
//
//
//////////////////////////////////////////////////////////////////////////////////////

/* 
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
 */
/* 
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
 */
/* 
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
 */
/* 
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

        uint[] memory globalPredictions = new uint[](3);
        globalPredictions[0] = uint(53);
        globalPredictions[1] = uint(63);
        globalPredictions[2] = uint(83);
        assertEq(distributor.getProbabilityDistribution(), globalPredictions);
        
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
    }

 */
/*         uint subTotal = alicePrediction[0]+bobPrediction[0];
        assertEq(collateralToken.balanceOf(address(alice)), initialBalance * alicePrediction[0] / subTotal);
        assertEq(collateralToken.balanceOf(address(bob)), initialBalance * bobPrediction[0] / subTotal); */

}
