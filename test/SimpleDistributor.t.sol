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
// relation between amount invested and returnedTokens
// create deep position distributors..
// check initialization+config on same fn (nope, CT logic requires 2 steps..)
// add other templates to see the basis stuff to start them?

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
        bob.setProbabilityDistribution(address(distributor), 0, bobPrediction, 'A long string to test storage issues');
        // *10 comes from a proportion given in the distributor
        //assertTrue(ISimpleDistributor(distributor).userSet(address(bob)));
        uint[] memory bobPosition = ISimpleDistributor(distributor).getUserPosition(address(bob));
        assertEq(bobPrediction[0]*10, bobPosition[0]);
        assertEq(bobPrediction[1]*10, bobPosition[1]);    
        assertEq(bobPrediction[2]*10, bobPosition[2]);    
    }

    function test_distribution_with_price() public {
        uint initial_amount = 10000;
        uint price_value = 500;
        address distributor = factory.getDistributorAddress(0);
        SimpleDistributor distributor_artifact = SimpleDistributor(distributor);
        collateralToken.mint(address(bob), price_value);
        collateralToken.mint(address(carol), price_value);
        alice.approveCollateral(distributor, initial_amount);
        alice.configure(
            factory.getDistributorAddress(0),
            initial_amount, //amountToSplit
            0, //timeOut (no limit)
            price_value, //price
            0 //fee
        );
        uint[] memory bobPrediction = new uint[](3);
        bobPrediction[0] = uint(2);
        bobPrediction[1] = uint(3);
        bobPrediction[2] = uint(5);
        bob.approveCollateral(address(distributor), price_value);
        vm.expectRevert(bytes("Price is bigger")); // checks it reverts if it is lower than min price 
        bob.setProbabilityDistribution(address(distributor), price_value-1, bobPrediction, 'A long string to test storage issues');
        bob.setProbabilityDistribution(address(distributor), price_value, bobPrediction, 'A long string to test storage issues');
//        assertTrue(ISimpleDistributor(distributor).userSet(address(bob)));
        assertEq(collateralToken.balanceOf(address(bob)), 0);
        assertEq(distributor_artifact.totalCollateral(), price_value + initial_amount);
        // update does not cost extra
        uint[] memory bobPrediction2 = new uint[](3);
        bobPrediction2[0] = uint(1);
        bobPrediction2[1] = uint(1);
        bobPrediction2[2] = uint(0);
        bob.setProbabilityDistribution(address(distributor), 0, bobPrediction, 'A long string to test storage issues');
        assertEq(distributor_artifact.totalCollateral(), price_value + initial_amount);
        uint[] memory carolPrediction = new uint[](3);
        carolPrediction[0] = uint(0);
        carolPrediction[1] = uint(1);
        carolPrediction[2] = uint(1);
        carol.approveCollateral(address(distributor), price_value);
        carol.setProbabilityDistribution(address(distributor), price_value, carolPrediction, 'A long string to test storage issues');
        //assertTrue(ISimpleDistributor(distributor).userSet(address(carol)));
        assertEq(collateralToken.balanceOf(address(carol)), 0);
        assertEq(distributor_artifact.totalCollateral(), 2*price_value + initial_amount);
        // test redeem amounts
    }

    function test_addFunds() public {
        address distributor = factory.getDistributorAddress(0);
        alice.approveCollateral(distributor, initialBalance);
        alice.configure(
            factory.getDistributorAddress(0),
            initialBalance, //amountToSplit
            0, //timeOut (no limit)
            0, //price
            0 //fee
        );
        collateralToken.mint(address(this), initialBalance);
        collateralToken.approve(address(distributor), initialBalance);
        SimpleDistributor distributor_artifact = SimpleDistributor(distributor);
        assertEq(distributor_artifact.totalCollateral(), initialBalance);
        bytes32 conditionId = QuestionsFactory(factory).getCondition(0);//question_index
        distributor_artifact.addFunds(initialBalance);
        assertEq(distributor_artifact.totalCollateral(), 2*initialBalance);
    }

    // add fuzz!
    function test_complete() public {
        bytes32 conditionId = QuestionsFactory(factory).getCondition(0);//question_index
        address distributor = factory.getDistributorAddress(0);
        collateralToken.mint(address(bob), 1);
        alice.approveCollateral(distributor, initialBalance);
        alice.configure(
            factory.getDistributorAddress(0),
            initialBalance-1, //amountToSplit
            0, //timeOut (no limit)
            0, //price
            0 //fee
        );        
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(2);
        alicePrediction[1] = uint(3);
        alicePrediction[2] = uint(5);
        alice.approveCollateral(distributor, 100);
        alice.setProbabilityDistribution(address(distributor),1, alicePrediction, justification2);

        uint[] memory bobPrediction = new uint[](3);
        bobPrediction[0] = uint(8);
        bobPrediction[1] = uint(8);
        bobPrediction[2] = uint(8);
        bob.approveCollateral(distributor, 100);
        bob.setProbabilityDistribution(address(distributor),1, bobPrediction, justification1);
//   alice.redemptionTime(distributor); //
        uint[] memory payout = new uint[](3);
        payout[0] = 1;
        payout[1] = 0;
        payout[2] = 0;
        oracle.reportPayouts(CT_gnosis, questionId1, payout);
// once its answered we need to make a call (that will revert)
        //vm.expectRevert(bytes("Question answered"));// reverts but without data
        //alice.setProbabilityDistribution(address(distributor),0, alicePrediction, '');
        alice.checkQuestion(distributor);
        uint[] memory globalPredictions = new uint[](3);
        globalPredictions[0] = uint(53);
        globalPredictions[1] = uint(63);
        globalPredictions[2] = uint(83);
        assertEq(SimpleDistributor(distributor).getProbabilityDistribution(), globalPredictions);
        
        SimpleDistributor(distributor).getUserRedemption(address(alice));
        SimpleDistributor(distributor).getUserRedemption(address(bob));

        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100
        
        alice.redeem(distributor);
        bob.redeem(distributor);

//        ICT(CT_gnosis).payoutDenominator(conditionId);
//        ICT(CT_gnosis).getOutcomeSlotCount(conditionId);
//        ICT(CT_gnosis).payoutNumerators(conditionId); //evm revert!
        ISimpleDistributor(distributor).getProbabilityDistribution();

        alice.redeemPositions(
            CT_gnosis,
            rootCollateral,
            conditionId,
            indexSets
        );
        bob.redeemPositions(
            CT_gnosis,
            rootCollateral,
            conditionId,
            indexSets
        );
        assertGt(collateralToken.balanceOf(address(alice)), 0);
        assertGt(collateralToken.balanceOf(address(bob)), 0);
    }
    
    function test_timeOut() public {
        bytes32 conditionId = QuestionsFactory(factory).getCondition(0);//question_index
        address distributor = factory.getDistributorAddress(0);
        alice.approveCollateral(distributor, initialBalance);
        alice.configure(
            factory.getDistributorAddress(0),
            initialBalance, //amountToSplit
            defaultTimeOut, //timeOut (no limit)
            0, //price
            0 //fee
        );        
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(2);
        alicePrediction[1] = uint(3);
        alicePrediction[2] = uint(5);
        alice.setProbabilityDistribution(address(distributor),0, alicePrediction, '');
        vm.warp(defaultTimeOut);
        vm.expectRevert(bytes("Time is out"));//
        alice.setProbabilityDistribution(address(distributor),0, alicePrediction, '');
        alice.changeTimeOut(distributor, defaultTimeOut + 1 days); // careful! this fn is left public
        alice.setProbabilityDistribution(address(distributor),0, alicePrediction, '');
    }
    function test_question_answered_notChecked() public {
        bytes32 conditionId = QuestionsFactory(factory).getCondition(0);//question_index
        address distributor = factory.getDistributorAddress(0);
        alice.approveCollateral(distributor, initialBalance);
        alice.configure(
            factory.getDistributorAddress(0),
            initialBalance, //amountToSplit
            defaultTimeOut, //timeOut (no limit)
            0, //price
            0 //fee
        );        
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(2);
        alicePrediction[1] = uint(3);
        alicePrediction[2] = uint(5);
        alice.setProbabilityDistribution(address(distributor),0, alicePrediction, '');
        uint[] memory vals = ISimpleDistributor(distributor).getUserPosition(address(alice));
        // answer question
        uint[] memory payout = new uint[](3);
        payout[0] = 1;
        payout[1] = 0;
        payout[2] = 0;
        oracle.reportPayouts(CT_gnosis, questionId1, payout);
        uint[] memory aliceNewPrediction = new uint[](3);
        aliceNewPrediction[0] = uint(1);
        aliceNewPrediction[1] = uint(0);
        aliceNewPrediction[2] = uint(0);
        alice.setProbabilityDistribution(address(distributor),0, aliceNewPrediction, '');
        // check contract state payout_numerator & denominator
        assertEq(ISimpleDistributor(distributor).question_denominator(), 1);
        uint[] memory vals_f = ISimpleDistributor(distributor).getUserPosition(address(alice));
        assertEq(vals_f[0], vals[0]);
        assertEq(vals_f[1], vals[1]);
        assertEq(vals_f[2], vals[2]);
    }
    function test_question_answered_checked() public {
        bytes32 conditionId = QuestionsFactory(factory).getCondition(0);//question_index
        address distributor = factory.getDistributorAddress(0);
        alice.approveCollateral(distributor, initialBalance);
        alice.configure(
            factory.getDistributorAddress(0),
            initialBalance, //amountToSplit
            defaultTimeOut, //timeOut (no limit)
            0, //price
            0 //fee
        );        
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(2);
        alicePrediction[1] = uint(3);
        alicePrediction[2] = uint(5);
        alice.setProbabilityDistribution(address(distributor),0, alicePrediction, '');
        uint[] memory payout = new uint[](3);
        payout[0] = 1;
        payout[1] = 0;
        payout[2] = 0;
        oracle.reportPayouts(CT_gnosis, questionId1, payout);
        alice.checkQuestion(distributor);
        vm.expectRevert(bytes("Question answered"));// reverts but without data
        alice.setProbabilityDistribution(address(distributor),0, alicePrediction, '');
        assertEq(ISimpleDistributor(distributor).question_denominator(), 1);
    }
    function test_positions_distribution_simple() public {
        ISimpleDistributor distributor = ISimpleDistributor(factory.getDistributorAddress(0));
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100
        bytes32 condition = distributor.conditionId();
        //uint positions_0 = distributor.positionIds(0);
        //uint positions_1 = distributor.positionIds(1);
        //uint positions_2 = distributor.positionIds(2);
        address d_address = address(distributor);
        collateralToken.mint(address(bob), initialBalance);
        collateralToken.mint(address(carol), initialBalance);
        collateralToken.mint(address(deedee), initialBalance);
        vm.prank(address(alice));
        collateralToken.approve(address(distributor), initialBalance);
        //alice.approveCollateral(d_address, initialBalance);
        vm.prank(address(alice));
        distributor.configure(
            3, //amountToSplit
            0, //timeOut (no limit)
            100, //price
            0 //fee
        );
        //////////////////////////////////////////////////  POSITIONS
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(10);
        alicePrediction[1] = uint(10);
        alicePrediction[2] = uint(30);
        vm.prank(address(alice));
        distributor.setProbabilityDistribution(100, alicePrediction, '');
        //alice.setProbabilityDistribution(address(distributor), 100, alicePrediction, '');
        uint[] memory bobPrediction = new uint[](3);
        bobPrediction[0] = uint(100);
        bobPrediction[1] = uint(300);
        bobPrediction[2] = uint(100);
        //bob.approveCollateral(d_address, initialBalance);
        vm.prank(address(bob));
        collateralToken.approve(address(distributor), initialBalance);
        vm.prank(address(bob));
        distributor.setProbabilityDistribution(100, bobPrediction, '');
        //bob.setProbabilityDistribution(address(distributor), 100, bobPrediction, '');
        uint[] memory carolPrediction = new uint[](3);
        carolPrediction[0] = uint(0);
        carolPrediction[1] = uint(2);
        carolPrediction[2] = uint(3);
//        carol.approveCollateral(d_address, initialBalance);
//        carol.setProbabilityDistribution(address(distributor), 100, carolPrediction, '');
        vm.prank(address(carol));
        collateralToken.approve(address(distributor), initialBalance);
        vm.prank(address(carol));
        distributor.setProbabilityDistribution(100, carolPrediction, '');

        ///////////////////////////////////////////////// ANSWER
        uint[] memory payout = new uint[](3);
        payout[0] = 1;
        payout[1] = 0;
        payout[2] = 0;
        vm.prank(address(oracle));
        ICT(CT_gnosis).reportPayouts(questionId1, payout);
//        oracle.reportPayouts(CT_gnosis, questionId1, payout);
        vm.prank(address(oracle));
        distributor.checkQuestion();
//        alice.checkQuestion(d_address);
        //////////////////////////////////////////////// RESULTS
        uint[] memory global = distributor.getProbabilityDistribution();        
        emit log_named_uint("total collateral:", distributor.totalCollateral());
        emit log_named_uint("GLOBAL Result 0:", uint256(global[0]));
        emit log_named_uint("GLOBAL Result 1:", uint256(global[1]));
        emit log_named_uint("GLOBAL Result 2:", uint256(global[2]));
//        emit log_string("PadIsNotLive()");
        uint[] memory Alice_returnedTokens = distributor.getUserRedemption(address(alice));
        emit log_named_uint("ALICE returned 0:", uint256(Alice_returnedTokens[0]));
        emit log_named_uint("ALICE returned 1:", uint256(Alice_returnedTokens[1]));
        emit log_named_uint("ALICE returned 2:", uint256(Alice_returnedTokens[2]));

        uint[] memory Bob_returnedTokens = distributor.getUserRedemption(address(bob));
        emit log_named_uint("BOB returned 0:", uint256(Bob_returnedTokens[0]));
        emit log_named_uint("BOB returned 1:", uint256(Bob_returnedTokens[1]));
        emit log_named_uint("BOB returned 2:", uint256(Bob_returnedTokens[2]));

        uint[] memory Carol_returnedTokens = distributor.getUserRedemption(address(carol));
        emit log_named_uint("CAROL returned 0:", uint256(Carol_returnedTokens[0]));
        emit log_named_uint("CAROL returned 1:", uint256(Carol_returnedTokens[1]));
        emit log_named_uint("CAROL returned 2:", uint256(Carol_returnedTokens[2]));

        //////////////////////////////////////////////// REDEMPTION
        vm.prank(address(alice));
        distributor.redeem();
        //assertEq(ICT(CT_gnosis).balanceOf(address(alice), positions_0), Alice_returnedTokens[0]);
        //assertEq(ICT(CT_gnosis).balanceOf(address(alice), positions_1), Alice_returnedTokens[1]);
        //assertEq(ICT(CT_gnosis).balanceOf(address(alice), positions_2), Alice_returnedTokens[2]);
        vm.prank(address(bob));
        distributor.redeem();        
        //assertEq(ICT(CT_gnosis).balanceOf(address(bob), positions_0), Bob_returnedTokens[0]);
        //assertEq(ICT(CT_gnosis).balanceOf(address(bob), positions_1), Bob_returnedTokens[1]);
        //assertEq(ICT(CT_gnosis).balanceOf(address(bob), positions_2), Bob_returnedTokens[2]);
        vm.prank(address(carol));
        distributor.redeem();        
        //assertEq(ICT(CT_gnosis).balanceOf(address(carol), positions_0), Carol_returnedTokens[0]);
        //assertEq(ICT(CT_gnosis).balanceOf(address(carol), positions_1), Carol_returnedTokens[1]);
        //assertEq(ICT(CT_gnosis).balanceOf(address(carol), positions_2), Carol_returnedTokens[2]);

/* 
        alice.redeemPositions(
            CT_gnosis,
            rootCollateral,
            condition,  // stack too deep (?)
            indexSets
        );
 */        
    }

    function test_weighted_positions() public {
        ISimpleDistributor distributor = ISimpleDistributor(factory.getDistributorAddress(0));
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100
        bytes32 condition = distributor.conditionId();
        uint positions_0 = distributor.positionIds(0);
        uint positions_1 = distributor.positionIds(1);
        uint positions_2 = distributor.positionIds(2);
        address d_address = address(distributor);
        alice.approveCollateral(d_address, initialBalance);
        collateralToken.mint(address(bob), initialBalance);
        collateralToken.mint(address(carol), initialBalance);
        collateralToken.mint(address(deedee), initialBalance);
        bob.approveCollateral(d_address, initialBalance);
        carol.approveCollateral(d_address, initialBalance);
        alice.configure(
            factory.getDistributorAddress(0),
            10, //amountToSplit
            0, //timeOut (no limit)
            10, //price
            0 //fee
        );
        //////////////////////////////////////////////////  POSITIONS
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(25);
        alicePrediction[1] = uint(75);
        alicePrediction[2] = uint(0);
        alice.setProbabilityDistribution(address(distributor), 100, alicePrediction, '');
        uint[] memory bobPrediction = new uint[](3);
        bobPrediction[0] = uint(25);
        bobPrediction[1] = uint(0);
        bobPrediction[2] = uint(75);
        bob.setProbabilityDistribution(address(distributor), 50, bobPrediction, '');
        uint[] memory carolPrediction = new uint[](3);
        carolPrediction[0] = uint(33);
        carolPrediction[1] = uint(33);
        carolPrediction[2] = uint(33);
        carol.setProbabilityDistribution(address(distributor), 10, carolPrediction, '');
        ///////////////////////////////////////////////// ANSWER
        uint[] memory payout = new uint[](3);
        payout[0] = 1;
        payout[1] = 0;
        payout[2] = 0;
        oracle.reportPayouts(CT_gnosis, questionId1, payout);
        alice.checkQuestion(d_address);
        //////////////////////////////////////////////// RESULTS
/*         uint[] memory global = distributor.getProbabilityDistribution();        
        emit log_named_uint("total collateral:", distributor.totalCollateral());
        emit log_named_uint("GLOBAL Result 0:", uint256(global[0]));
        emit log_named_uint("GLOBAL Result 1:", uint256(global[1]));
        emit log_named_uint("GLOBAL Result 2:", uint256(global[2]));
//        emit log_string("PadIsNotLive()");
        uint[] memory Alice_returnedTokens = distributor.getUserRedemption(address(alice));
        emit log_named_uint("ALICE returned 0:", uint256(Alice_returnedTokens[0]));
        emit log_named_uint("ALICE returned 1:", uint256(Alice_returnedTokens[1]));
        emit log_named_uint("ALICE returned 2:", uint256(Alice_returnedTokens[2]));

        uint[] memory Bob_returnedTokens = distributor.getUserRedemption(address(bob));
        emit log_named_uint("BOB returned 0:", uint256(Bob_returnedTokens[0]));
        emit log_named_uint("BOB returned 1:", uint256(Bob_returnedTokens[1]));
        emit log_named_uint("BOB returned 2:", uint256(Bob_returnedTokens[2]));

        uint[] memory Carol_returnedTokens = distributor.getUserRedemption(address(carol));
        emit log_named_uint("CAROL returned 0:", uint256(Carol_returnedTokens[0]));
        emit log_named_uint("CAROL returned 1:", uint256(Carol_returnedTokens[1]));
        emit log_named_uint("CAROL returned 2:", uint256(Carol_returnedTokens[2]));
 */
        //////////////////////////////////////////////// REDEMPTION
        alice.redeem(d_address);
   //     assertEq(ICT(CT_gnosis).balanceOf(address(alice), positions_0), Alice_returnedTokens[0]);
   //     assertEq(ICT(CT_gnosis).balanceOf(address(alice), positions_1), Alice_returnedTokens[1]);
   //     assertEq(ICT(CT_gnosis).balanceOf(address(alice), positions_2), Alice_returnedTokens[2]);
        bob.redeem(d_address);        
   //     assertEq(ICT(CT_gnosis).balanceOf(address(bob), positions_0), Bob_returnedTokens[0]);
   //     assertEq(ICT(CT_gnosis).balanceOf(address(bob), positions_1), Bob_returnedTokens[1]);
   //     assertEq(ICT(CT_gnosis).balanceOf(address(bob), positions_2), Bob_returnedTokens[2]);
        carol.redeem(d_address);        
   //     assertEq(ICT(CT_gnosis).balanceOf(address(carol), positions_0), Carol_returnedTokens[0]);
   //     assertEq(ICT(CT_gnosis).balanceOf(address(carol), positions_1), Carol_returnedTokens[1]);
   //     assertEq(ICT(CT_gnosis).balanceOf(address(carol), positions_2), Carol_returnedTokens[2]);        
        //////////////////////////////////////////////// GETTING COLLATERAL
        userRedeemsCollateral(address(alice), condition, indexSets);
        userRedeemsCollateral(address(bob), condition, indexSets);
        userRedeemsCollateral(address(carol), condition, indexSets);

        
    }

    function userRedeemsCollateral(address user, bytes32 condition, uint256[] memory indexSets) public {
        vm.prank(user);
        ICT(CT_gnosis).redeemPositions(
            collateralToken, 
            rootCollateral, 
            condition, 
            indexSets
        );
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



/*         uint subTotal = alicePrediction[0]+bobPrediction[0];
        assertEq(collateralToken.balanceOf(address(alice)), initialBalance * alicePrediction[0] / subTotal);
        assertEq(collateralToken.balanceOf(address(bob)), initialBalance * bobPrediction[0] / subTotal); */

}
