// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

//import "../interfaces/User.sol";
/* import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol"; */
import "../interfaces/ICT.sol";
import "../src/SimpleDistributor.sol";
import "../src/OpinologoFactory.sol";
import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

// TODO
// create deep position distributors..
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
    
    uint256 constant PRECISION = 1e18;
    uint initialBalance = 100 * PRECISION;

    uint defaultTimeOut = block.timestamp + 1 days;

    QuestionsFactory factory;
    SimpleDistributor distributor_template;
    ERC20PresetMinterPauser collateralToken;

    address oracle;
    address alice;
    address bob;
    address carol;
    address deedee;
    address distributor_address;

    function setUp() public {
        distributor_template = new SimpleDistributor();
        collateralToken = new ERC20PresetMinterPauser("FakeUSD", "FUSD");
        factory = new QuestionsFactory(CT_gnosis);
        ////////////////// USERS
        vm.label(address(this), "Test Contract");
        vm.label(address(collateralToken), "Token Contract");
        vm.label(address(factory), "Factory");
        oracle = address(0);
        vm.label(address(0), "Oracle");
        alice = address(1);
        vm.label(address(1), "Alice");
        bob = address(2);
        vm.label(address(2), "Bob");
        carol = address(3);
        vm.label(address(3), "Carol");
        deedee = address(4);
        vm.label(address(4), "deedee");
        collateralToken.mint(address(1), initialBalance);
        collateralToken.mint(address(2), initialBalance);
        collateralToken.mint(address(3), initialBalance);
        collateralToken.mint(address(4), initialBalance);
        //////////////////
        factory.setTemplate(address(distributor_template), 0);
        factory.grantRole(CREATOR_ROLE, address(this));
        bytes32 condition_created = factory.createQuestion(oracle, questionId1, 3);
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100
        vm.prank(alice);
        factory.createDistributor(
            rootCollateral,
            address(collateralToken),
            indexSets,
            0, // template index
            0  // question index
        );                 
        distributor_address = factory.getDistributorAddress(0);
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

    function test_configuration_prepares_distributor() public {
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100
        uint initial_amount = 10000;
        vm.prank(alice);
        collateralToken.approve(distributor_address, initial_amount);
        vm.prank(alice);
        ISimpleDistributor(distributor_address).configure(
            initial_amount, 
            0, 
            0, 
            0
        );
        assertEq(ICT(CT_gnosis).getOutcomeSlotCount(factory.getCondition(0)), 3);        
        for (uint i=0; i < 3; i++) {
            (bytes32 condition, uint position) = getCollectionAndPosition(
                address(collateralToken),
                factory.getParentCollection(0),
                factory.getCondition(0),
                indexSets[i]
            );
            assertEq(ICT(CT_gnosis).balanceOf(distributor_address, position), initial_amount);
        }

    }

    function test_user_can_set_distribution() public {
        uint initial_amount = 10000;
        uint[] memory bobPrediction = new uint[](3);
        bobPrediction[0] = uint(2);
        bobPrediction[1] = uint(3);
        bobPrediction[2] = uint(5);
        vm.prank(alice);
        collateralToken.approve(distributor_address, initial_amount);
        // previous to config the distributor should reject users
        vm.expectRevert(bytes('Contract not open'));
        vm.prank(bob);        
        ISimpleDistributor(distributor_address).setProbabilityDistribution(0, bobPrediction, 'A long string to test storage issues');
        vm.prank(alice);
        ISimpleDistributor(distributor_address).configure(
            initial_amount, //amountToSplit
            0, //timeOut (no limit)
            0, //price
            0 //fee
        );
        vm.prank(bob);
        ISimpleDistributor(distributor_address).setProbabilityDistribution(0, bobPrediction, 'A long string to test storage issues');
        // *10 comes from a proportion given in the distributor
        //assertTrue(ISimpleDistributor(distributor).userSet(address(bob)));
        uint[] memory bobPosition = ISimpleDistributor(distributor_address).getUserPosition(bob);
        assertEq(bobPrediction[0]*10, bobPosition[0]);
        assertEq(bobPrediction[1]*10, bobPosition[1]);    
        assertEq(bobPrediction[2]*10, bobPosition[2]);    
    }
    
    // TODO: lots of testing in here, dissect it to multiple unit tests
    function test_distribution_with_price_update_for_free() public {
        uint initial_amount = 10000;
        uint price_value = 500;
        vm.prank(alice);
        collateralToken.approve(distributor_address, initial_amount);
        vm.prank(alice);
        ISimpleDistributor(distributor_address).configure(
            initial_amount, //amountToSplit
            0, //timeOut (no limit)
            price_value, //price
            0 //fee
        );
        uint[] memory bobPrediction = new uint[](3);
        bobPrediction[0] = uint(2);
        bobPrediction[1] = uint(3);
        bobPrediction[2] = uint(5);
        vm.prank(bob);
        collateralToken.approve(distributor_address, price_value);
        vm.prank(bob);
        vm.expectRevert(bytes("Price is bigger")); // checks it reverts if it is lower than min price 
        ISimpleDistributor(distributor_address).setProbabilityDistribution(price_value-1, bobPrediction, 'A long string to test storage issues');
        vm.prank(bob);
        ISimpleDistributor(distributor_address).setProbabilityDistribution(price_value, bobPrediction, 'A long string to test storage issues');
        assertEq(collateralToken.balanceOf(address(bob)), initialBalance - price_value);
        assertEq(ISimpleDistributor(distributor_address).totalCollateral(), price_value + initial_amount);
        // update does not cost extra (override the array for simplicity)
        bobPrediction[0] = uint(1);
        bobPrediction[1] = uint(1);
        bobPrediction[2] = uint(0);
        vm.prank(bob);
        ISimpleDistributor(distributor_address).setProbabilityDistribution(0, bobPrediction, 'A long string to test storage issues');
        assertEq(ISimpleDistributor(distributor_address).totalCollateral(), price_value + initial_amount);
        uint[] memory bobPosition = ISimpleDistributor(distributor_address).getUserPosition(bob);
        assertEq(50, bobPosition[0]);
        assertEq(50, bobPosition[1]);    
        assertEq(0, bobPosition[2]);   
    }

    function test_add_funds() public {
        vm.prank(alice);
        collateralToken.approve(distributor_address, initialBalance);
        vm.prank(alice);
        ISimpleDistributor(distributor_address).configure(
            initialBalance, //amountToSplit
            0, //timeOut (no limit)
            0, //price
            0 //fee
        );
        vm.prank(bob);
        collateralToken.approve(distributor_address, initialBalance);
        assertEq(ISimpleDistributor(distributor_address).totalCollateral(), initialBalance);
        vm.prank(bob);
        ISimpleDistributor(distributor_address).addFunds(initialBalance);
        assertEq(ISimpleDistributor(distributor_address).totalCollateral(), 2*initialBalance);
        // after question is answered should revert
        vm.prank(carol);
        collateralToken.approve(distributor_address, initialBalance);
        uint[] memory response = new uint[](3);
        response[0] = uint(1);
        response[1] = uint(0);
        response[2] = uint(0);
        vm.prank(oracle);
        ICT(CT_gnosis).reportPayouts(questionId1, response);
        vm.prank(oracle);
        ISimpleDistributor(distributor_address).checkQuestion();
        vm.expectRevert(bytes('Question answered'));
        vm.prank(carol);
        ISimpleDistributor(distributor_address).addFunds(initialBalance);        
    }
    function test_timeOut() public {
        vm.prank(alice);
        collateralToken.approve(distributor_address, initialBalance);
        vm.prank(alice);
        ISimpleDistributor(distributor_address).configure(
            initialBalance, //amountToSplit
            defaultTimeOut, //timeOut (no limit)
            0, //price
            0 //fee
        );        
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(2);
        alicePrediction[1] = uint(3);
        alicePrediction[2] = uint(5);
        vm.prank(alice);
        ISimpleDistributor(distributor_address).setProbabilityDistribution(0, alicePrediction, '');
        vm.warp(defaultTimeOut);
        vm.expectRevert(bytes("Time is out"));//
        vm.prank(alice);
        ISimpleDistributor(distributor_address).setProbabilityDistribution(0, alicePrediction, '');
        vm.expectRevert(bytes('Only moderators can change'));
        vm.prank(alice);
        ISimpleDistributor(distributor_address).changeTimeOut(defaultTimeOut + 1 days); 
        // change timeout via a manager
        factory.grantRole(MANAGER_ROLE, alice);
        vm.prank(alice);
        factory.changeDistributorTimeout(0, defaultTimeOut + 1 days); 
        vm.prank(alice);
        ISimpleDistributor(distributor_address).setProbabilityDistribution(0, alicePrediction, '');
        // if answered, should revert
        uint[] memory payout = new uint[](3);
        payout[0] = 1;
        payout[1] = 0;
        payout[2] = 0;
        vm.prank(oracle);
        ICT(CT_gnosis).reportPayouts(questionId1, payout);
        ISimpleDistributor(distributor_address).checkQuestion();
        vm.expectRevert(bytes('Question answered'));
        vm.prank(alice);
        ISimpleDistributor(distributor_address).changeTimeOut(defaultTimeOut + 1 days); 
    }
    // continue here
    function test_question_answered_notChecked() public {
        vm.prank(alice);
        collateralToken.approve(distributor_address, initialBalance);
        vm.prank(alice);
        ISimpleDistributor(distributor_address).configure(
            initialBalance, //amountToSplit
            defaultTimeOut, //timeOut (no limit)
            0, //price
            0 //fee
        );        
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(2);
        alicePrediction[1] = uint(3);
        alicePrediction[2] = uint(5);
        vm.prank(alice);
        ISimpleDistributor(distributor_address).setProbabilityDistribution(0, alicePrediction, '');
        uint[] memory vals = ISimpleDistributor(distributor_address).getUserPosition(alice);
        // answer question
        uint[] memory payout = new uint[](3);
        payout[0] = 1;
        payout[1] = 0;
        payout[2] = 0;
        vm.prank(oracle);
        ICT(CT_gnosis).reportPayouts(questionId1, payout);
        uint[] memory aliceNewPrediction = new uint[](3);
        aliceNewPrediction[0] = uint(1);
        aliceNewPrediction[1] = uint(0);
        aliceNewPrediction[2] = uint(0);
        vm.prank(alice);
        ISimpleDistributor(distributor_address).setProbabilityDistribution(0, aliceNewPrediction, '');
        // check contract state payout_numerator & denominator
        assertEq(ISimpleDistributor(distributor_address).question_denominator(), 1);
        uint[] memory vals_f = ISimpleDistributor(distributor_address).getUserPosition(alice);
        assertEq(vals_f[0], vals[0]);
        assertEq(vals_f[1], vals[1]);
        assertEq(vals_f[2], vals[2]);
    }

    function test_question_answered_checked() public {
        vm.prank(alice);
        collateralToken.approve(distributor_address, initialBalance);
        vm.prank(alice);
        ISimpleDistributor(distributor_address).configure(
            initialBalance, //amountToSplit
            defaultTimeOut, //timeOut (no limit)
            0, //price
            0 //fee
        );        
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(2);
        alicePrediction[1] = uint(3);
        alicePrediction[2] = uint(5);
        vm.prank(alice);
        ISimpleDistributor(distributor_address).setProbabilityDistribution(0, alicePrediction, '');
        uint[] memory payout = new uint[](3);
        payout[0] = 1;
        payout[1] = 0;
        payout[2] = 0;
        vm.prank(oracle);
        ICT(CT_gnosis).reportPayouts(questionId1, payout);
        vm.prank(alice);
        ISimpleDistributor(distributor_address).checkQuestion();
        vm.expectRevert(bytes("Question answered"));// reverts but without data
        vm.prank(alice);
        ISimpleDistributor(distributor_address).setProbabilityDistribution(0, alicePrediction, '');
        assertEq(ISimpleDistributor(distributor_address).question_denominator(), 1);
    }
    function test_positions_distribution_simple() public {
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100
        uint positions_0 = ISimpleDistributor(distributor_address).positionIds(0);
        uint positions_1 = ISimpleDistributor(distributor_address).positionIds(1);
        uint positions_2 = ISimpleDistributor(distributor_address).positionIds(2);
        vm.prank(alice);
        collateralToken.approve(distributor_address, initialBalance);
        vm.prank(alice);
        ISimpleDistributor(distributor_address).configure(
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
        vm.prank(alice);
        ISimpleDistributor(distributor_address).setProbabilityDistribution(100, alicePrediction, '');
        uint[] memory bobPrediction = new uint[](3);
        bobPrediction[0] = uint(100);
        bobPrediction[1] = uint(300);
        bobPrediction[2] = uint(100);
        vm.prank(bob);
        collateralToken.approve(distributor_address, initialBalance);
        vm.prank(bob);
        ISimpleDistributor(distributor_address).setProbabilityDistribution(100, bobPrediction, '');
        uint[] memory carolPrediction = new uint[](3);
        carolPrediction[0] = uint(0);
        carolPrediction[1] = uint(2);
        carolPrediction[2] = uint(3);
        vm.prank(carol);
        collateralToken.approve(distributor_address, initialBalance);
        vm.prank(carol);
        ISimpleDistributor(distributor_address).setProbabilityDistribution(100, carolPrediction, '');

        ///////////////////////////////////////////////// ANSWER
        uint[] memory payout = new uint[](3);
        payout[0] = 1;
        payout[1] = 0;
        payout[2] = 0;
        vm.prank(oracle);
        ICT(CT_gnosis).reportPayouts(questionId1, payout);
        vm.prank(oracle);
        ISimpleDistributor(distributor_address).checkQuestion();
        //////////////////////////////////////////////// RESULTS
        uint[] memory global = ISimpleDistributor(distributor_address).getProbabilityDistribution();        
        emit log_named_uint("total collateral:", ISimpleDistributor(distributor_address).totalCollateral());
        emit log_named_uint("GLOBAL Result 0:", uint256(global[0]));
        emit log_named_uint("GLOBAL Result 1:", uint256(global[1]));
        emit log_named_uint("GLOBAL Result 2:", uint256(global[2]));
//        emit log_string("PadIsNotLive()");
        uint[] memory Alice_returnedTokens = ISimpleDistributor(distributor_address).getUserRedemption(address(alice));
        emit log_named_uint("ALICE returned 0:", uint256(Alice_returnedTokens[0]));
        emit log_named_uint("ALICE returned 1:", uint256(Alice_returnedTokens[1]));
        emit log_named_uint("ALICE returned 2:", uint256(Alice_returnedTokens[2]));

        uint[] memory Bob_returnedTokens = ISimpleDistributor(distributor_address).getUserRedemption(address(bob));
        emit log_named_uint("BOB returned 0:", uint256(Bob_returnedTokens[0]));
        emit log_named_uint("BOB returned 1:", uint256(Bob_returnedTokens[1]));
        emit log_named_uint("BOB returned 2:", uint256(Bob_returnedTokens[2]));

        uint[] memory Carol_returnedTokens = ISimpleDistributor(distributor_address).getUserRedemption(address(carol));
        emit log_named_uint("CAROL returned 0:", uint256(Carol_returnedTokens[0]));
        emit log_named_uint("CAROL returned 1:", uint256(Carol_returnedTokens[1]));
        emit log_named_uint("CAROL returned 2:", uint256(Carol_returnedTokens[2]));

        //////////////////////////////////////////////// REDEMPTION
        vm.prank(alice);
        ISimpleDistributor(distributor_address).redeem();
        assertEq(ICT(CT_gnosis).balanceOf(alice, positions_0), Alice_returnedTokens[0]);
        assertEq(ICT(CT_gnosis).balanceOf(alice, positions_1), Alice_returnedTokens[1]);
        assertEq(ICT(CT_gnosis).balanceOf(alice, positions_2), Alice_returnedTokens[2]);
        vm.prank(bob);
        ISimpleDistributor(distributor_address).redeem();        
        assertEq(ICT(CT_gnosis).balanceOf(bob, positions_0), Bob_returnedTokens[0]);
        assertEq(ICT(CT_gnosis).balanceOf(bob, positions_1), Bob_returnedTokens[1]);
        assertEq(ICT(CT_gnosis).balanceOf(bob, positions_2), Bob_returnedTokens[2]);
        vm.prank(carol);
        ISimpleDistributor(distributor_address).redeem();        
        assertEq(ICT(CT_gnosis).balanceOf(carol, positions_0), Carol_returnedTokens[0]);
        assertEq(ICT(CT_gnosis).balanceOf(carol, positions_1), Carol_returnedTokens[1]);
        assertEq(ICT(CT_gnosis).balanceOf(carol, positions_2), Carol_returnedTokens[2]);

    }

    function test_weighted_positions() public {
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100
        uint positions_0 = ISimpleDistributor(distributor_address).positionIds(0);
        uint positions_1 = ISimpleDistributor(distributor_address).positionIds(1);
        uint positions_2 = ISimpleDistributor(distributor_address).positionIds(2);
        vm.prank(alice);
        collateralToken.approve(distributor_address, initialBalance);
        vm.prank(bob);
        collateralToken.approve(distributor_address, initialBalance);
        vm.prank(carol);
        collateralToken.approve(distributor_address, initialBalance);
        vm.prank(alice);
        ISimpleDistributor(distributor_address).configure(
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
        vm.prank(alice);
        ISimpleDistributor(distributor_address).setProbabilityDistribution(100, alicePrediction, '');
        uint[] memory bobPrediction = new uint[](3);
        bobPrediction[0] = uint(25);
        bobPrediction[1] = uint(0);
        bobPrediction[2] = uint(75);
        vm.prank(bob);
        ISimpleDistributor(distributor_address).setProbabilityDistribution(50, bobPrediction, '');
        uint[] memory carolPrediction = new uint[](3);
        carolPrediction[0] = uint(33);
        carolPrediction[1] = uint(33);
        carolPrediction[2] = uint(33);
        vm.prank(carol);
        ISimpleDistributor(distributor_address).setProbabilityDistribution(10, carolPrediction, '');
        ///////////////////////////////////////////////// ANSWER
        uint[] memory payout = new uint[](3);
        payout[0] = 1;
        payout[1] = 0;
        payout[2] = 0;
        vm.prank(oracle);
        ICT(CT_gnosis).reportPayouts(questionId1, payout);
        vm.prank(alice);
        ISimpleDistributor(distributor_address).checkQuestion();
        //////////////////////////////////////////////// RESULTS
        uint[] memory global = ISimpleDistributor(distributor_address).getProbabilityDistribution();        
        emit log_named_uint("total collateral:", ISimpleDistributor(distributor_address).totalCollateral());
        emit log_named_uint("GLOBAL Result 0:", uint256(global[0]));
        emit log_named_uint("GLOBAL Result 1:", uint256(global[1]));
        emit log_named_uint("GLOBAL Result 2:", uint256(global[2]));
//        emit log_string("PadIsNotLive()");
        uint[] memory Alice_returnedTokens = ISimpleDistributor(distributor_address).getUserRedemption(address(alice));
        emit log_named_uint("ALICE returned 0:", uint256(Alice_returnedTokens[0]));
        emit log_named_uint("ALICE returned 1:", uint256(Alice_returnedTokens[1]));
        emit log_named_uint("ALICE returned 2:", uint256(Alice_returnedTokens[2]));

        uint[] memory Bob_returnedTokens = ISimpleDistributor(distributor_address).getUserRedemption(address(bob));
        emit log_named_uint("BOB returned 0:", uint256(Bob_returnedTokens[0]));
        emit log_named_uint("BOB returned 1:", uint256(Bob_returnedTokens[1]));
        emit log_named_uint("BOB returned 2:", uint256(Bob_returnedTokens[2]));

        uint[] memory Carol_returnedTokens = ISimpleDistributor(distributor_address).getUserRedemption(address(carol));
        emit log_named_uint("CAROL returned 0:", uint256(Carol_returnedTokens[0]));
        emit log_named_uint("CAROL returned 1:", uint256(Carol_returnedTokens[1]));
        emit log_named_uint("CAROL returned 2:", uint256(Carol_returnedTokens[2]));

        //////////////////////////////////////////////// REDEMPTION
        vm.prank(alice);
        ISimpleDistributor(distributor_address).redeem();
        assertEq(ICT(CT_gnosis).balanceOf(address(alice), positions_0), Alice_returnedTokens[0]);
        assertEq(ICT(CT_gnosis).balanceOf(address(alice), positions_1), Alice_returnedTokens[1]);
        assertEq(ICT(CT_gnosis).balanceOf(address(alice), positions_2), Alice_returnedTokens[2]);
        vm.prank(bob);
        ISimpleDistributor(distributor_address).redeem();        
        assertEq(ICT(CT_gnosis).balanceOf(address(bob), positions_0), Bob_returnedTokens[0]);
        assertEq(ICT(CT_gnosis).balanceOf(address(bob), positions_1), Bob_returnedTokens[1]);
        assertEq(ICT(CT_gnosis).balanceOf(address(bob), positions_2), Bob_returnedTokens[2]);
        vm.prank(carol);
        ISimpleDistributor(distributor_address).redeem();        
        assertEq(ICT(CT_gnosis).balanceOf(address(carol), positions_0), Carol_returnedTokens[0]);
        assertEq(ICT(CT_gnosis).balanceOf(address(carol), positions_1), Carol_returnedTokens[1]);
        assertEq(ICT(CT_gnosis).balanceOf(address(carol), positions_2), Carol_returnedTokens[2]);        
        //////////////////////////////////////////////// GETTING COLLATERAL
        bytes32 condition = factory.getCondition(0);
        userRedeemsCollateral(alice, condition, indexSets);
        userRedeemsCollateral(bob, condition, indexSets);
        userRedeemsCollateral(carol, condition, indexSets);        
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

    // add fuzz!


}
