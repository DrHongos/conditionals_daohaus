// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

//import "../interfaces/User.sol";
/* import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol"; */
import "../interfaces/ICT.sol";
import "../interfaces/IDistributor.sol";
import "../src/Distributor.sol";
import "../src/OpinologoFactory.sol";
import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

// TODO

contract DistributorNewTest is Test, ERC1155Holder {

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

    // question's
    bytes32 condition1;
    uint[] sets1 = new uint[](3);
    bytes32 condition2;
    uint[] sets2 = new uint[](2);
    bytes32 condition3;
    uint[] sets3 = new uint[](3);
    
    OpinologosFactory factory;
    Distributor distributor_template;
    ERC20PresetMinterPauser collateralToken;

    address oracle;
    address alice;
    address bob;
    address carol;
    address deedee;

    address distributor1;
    address distributor2;
    address distributor3;

    function setUp() public {
        distributor_template = new Distributor();
        collateralToken = new ERC20PresetMinterPauser("FakeUSD", "FUSD");
        factory = new OpinologosFactory(CT_gnosis);
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
        condition1 = factory.createQuestion(oracle, questionId1, 3);
        sets1[0] = uint(1); //0b001        
        sets1[1] = uint(2); //0b010       
        sets1[2] = uint(4); //0b100

        condition2 = factory.createQuestion(oracle, questionId2, 2);
        sets2[0] = uint(1); //0b001        
        sets2[1] = uint(2); //0b010       

        condition3 = factory.createQuestion(oracle, questionId3, 3);
        sets3[0] = uint(1); //0b001        
        sets3[1] = uint(2); //0b010       
        sets3[2] = uint(4); //0b100

        vm.prank(alice);
    }
///////////////////////////////////////////////// HELPERS
    function getCollectionAndPosition(
        address collateral,
        bytes32 parentCollection,
        bytes32 conditionId,
        uint indexSet
    ) public view returns (bytes32,uint) {
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

    function test_configuration_initial_balance() public {
        distributor1 = factory.createDistributor(
            rootCollateral,
            condition1,
            address(collateralToken),
            sets1,
            0 // template index
        );
        vm.label(distributor1, "Distributor for Q1");        
        // split collateral into the correspondent conditionals
        vm.startPrank(alice);
        uint amount = 100;
        collateralToken.approve(CT_gnosis, 100);
        ICT(CT_gnosis).splitPosition(       // shallow split
            collateralToken, 
            rootCollateral, 
            condition1, 
            sets1, 
            amount
        );
        vm.expectRevert(bytes('Insufficient allowance for conditional'));//
        IDistributor(distributor1).configure(
            amount,
            0, //_timeout
            0, //_price
            0//_fee
        );
        ICT(CT_gnosis).setApprovalForAll(distributor1, true);
        vm.expectRevert(bytes('Insufficient balance of conditional')); //
        IDistributor(distributor1).configure(
            amount + 1,
            0, //_timeout
            0, //_price
            0//_fee
        );
        // finally pass
        IDistributor(distributor1).configure(
            amount,
            0, //_timeout
            0, //_price
            0//_fee
        );
        // check balances of user and distributor
        uint[] memory positions = new uint[](3);
        positions[0]=IDistributor(distributor1).positionIds(0);
        positions[1]=IDistributor(distributor1).positionIds(1);
        positions[2]=IDistributor(distributor1).positionIds(2);
        address[] memory dummy_distributor = new address[](3);
        dummy_distributor[0]=distributor1;
        dummy_distributor[1]=distributor1;
        dummy_distributor[2]=distributor1;
        address[] memory dummy_alice = new address[](3);
        dummy_alice[0]= alice;
        dummy_alice[1]= alice;
        dummy_alice[2]= alice;
        uint[] memory distributor_balance = ICT(CT_gnosis).balanceOfBatch(dummy_distributor, positions);
        uint[] memory alice_balance = ICT(CT_gnosis).balanceOfBatch(dummy_alice, positions);
        for (uint i = 0; i < positions.length; i++) {
            assertEq(distributor_balance[i], amount);
            assertEq(alice_balance[i], 0);
        }
    }
    
    function test_user_can_set_distribution() public {
        distributor1 = factory.createDistributor(
            rootCollateral,
            condition1,
            address(collateralToken),
            sets1,
            0 // template index
        );
        vm.label(distributor1, "Distributor for Q1");        
        // split collateral into the correspondent conditionals
        vm.startPrank(alice);
        uint amount = 100;
        collateralToken.approve(CT_gnosis, amount);
        ICT(CT_gnosis).splitPosition(       // shallow split
            collateralToken, 
            rootCollateral, 
            condition1, 
            sets1, 
            amount
        );
        ICT(CT_gnosis).setApprovalForAll(distributor1, true);
        IDistributor(distributor1).configure(
            amount,
            0, //_timeout
            0, //_price
            0//_fee
        );
        vm.stopPrank();        
        uint[] memory bobPrediction = new uint[](3);
        bobPrediction[0] = uint(2);
        bobPrediction[1] = uint(3);
        bobPrediction[2] = uint(5);
        vm.startPrank(bob);
        collateralToken.approve(CT_gnosis, amount);
        ICT(CT_gnosis).splitPosition(       // shallow split
            collateralToken, 
            rootCollateral, 
            condition1, 
            sets1, 
            amount
        );
        ICT(CT_gnosis).setApprovalForAll(distributor1, true);
        IDistributor(distributor1).setProbabilityDistribution(0, bobPrediction, 'A long string to test storage issues');
        // *10 comes from a proportion given in the distributor
        uint[] memory bobPosition = IDistributor(distributor1).getUserPosition(bob);
        assertEq(bobPrediction[0]*10, bobPosition[0]);
        assertEq(bobPrediction[1]*10, bobPosition[1]);    
        assertEq(bobPrediction[2]*10, bobPosition[2]);    
    }
    
    function test_distribution_with_price_update_for_free() public {
        distributor1 = factory.createDistributor(
            rootCollateral,
            condition1,
            address(collateralToken),
            sets1,
            0 // template index
        );
        vm.label(distributor1, "Distributor for Q1");        
        // split collateral into the correspondent conditionals
        vm.startPrank(alice);
        uint amount = 100;
        collateralToken.approve(CT_gnosis, amount);
        ICT(CT_gnosis).splitPosition(       // shallow split
            collateralToken, 
            rootCollateral, 
            condition1, 
            sets1, 
            amount
        );
        ICT(CT_gnosis).setApprovalForAll(distributor1, true);
        IDistributor(distributor1).configure(
            amount,
            0, //_timeout
            amount, //_price
            0//_fee
        );
        vm.stopPrank();        
        uint[] memory bobPrediction = new uint[](3);
        bobPrediction[0] = uint(2);
        bobPrediction[1] = uint(3);
        bobPrediction[2] = uint(5);
        vm.startPrank(bob);
        collateralToken.approve(CT_gnosis, amount);
        ICT(CT_gnosis).splitPosition(       // shallow split
            collateralToken, 
            rootCollateral, 
            condition1, 
            sets1, 
            amount
        );
        ICT(CT_gnosis).setApprovalForAll(distributor1, true);
        vm.expectRevert(bytes("Price is bigger")); // checks it reverts if it is lower than min price 
        IDistributor(distributor1).setProbabilityDistribution(amount-1, bobPrediction, 'A long string to test storage issues');
        IDistributor(distributor1).setProbabilityDistribution(amount, bobPrediction, 'A long string to test storage issues');
        assertEq(collateralToken.balanceOf(address(bob)), initialBalance - amount);
        assertEq(IDistributor(distributor1).totalBalance(), 2*amount);
        // update does not cost extra (override the array for simplicity)
        bobPrediction[0] = uint(1);
        bobPrediction[1] = uint(1);
        bobPrediction[2] = uint(0);
        IDistributor(distributor1).setProbabilityDistribution(0, bobPrediction, 'A long string to test storage issues');
        assertEq(IDistributor(distributor1).totalBalance(), 2*amount);
        uint[] memory bobPosition = IDistributor(distributor1).getUserPosition(bob);
        assertEq(50, bobPosition[0]);
        assertEq(50, bobPosition[1]);    
        assertEq(0, bobPosition[2]);   
    }

    function test_add_funds() public {
        distributor1 = factory.createDistributor(
            rootCollateral,
            condition1,
            address(collateralToken),
            sets1,
            0 // template index
        );
        vm.label(distributor1, "Distributor for Q1");        
        // split collateral into the correspondent conditionals
        vm.startPrank(alice);
        uint amount = 100;
        collateralToken.approve(CT_gnosis, amount);
        ICT(CT_gnosis).splitPosition(       // shallow split
            collateralToken, 
            rootCollateral, 
            condition1, 
            sets1, 
            amount
        );
        ICT(CT_gnosis).setApprovalForAll(distributor1, true);
        IDistributor(distributor1).configure(
            amount,
            0, //_timeout
            0, //_price
            0//_fee
        );
        vm.stopPrank();
        vm.startPrank(bob);
        collateralToken.approve(CT_gnosis, amount);
        ICT(CT_gnosis).splitPosition(       // shallow split
            collateralToken, 
            rootCollateral, 
            condition1, 
            sets1, 
            amount
        );
        ICT(CT_gnosis).setApprovalForAll(distributor1, true);
        assertEq(IDistributor(distributor1).totalBalance(), amount);
        IDistributor(distributor1).addFunds(amount);
        assertEq(IDistributor(distributor1).totalBalance(), 2*amount);
        // after question is answered should revert
        vm.stopPrank();
        vm.prank(carol);
        collateralToken.approve(distributor1, amount);
        uint[] memory response = new uint[](3);
        response[0] = uint(1);
        response[1] = uint(0);
        response[2] = uint(0);
        vm.prank(oracle);
        ICT(CT_gnosis).reportPayouts(questionId1, response);
        vm.prank(oracle);
        IDistributor(distributor1).checkQuestion();
        vm.expectRevert(bytes('Question answered'));
        vm.prank(carol);
        IDistributor(distributor1).addFunds(amount);        
    }
    function test_timeOut() public {
        distributor1 = factory.createDistributor(
            rootCollateral,
            condition1,
            address(collateralToken),
            sets1,
            0 // template index
        );
        vm.label(distributor1, "Distributor for Q1");        
        // split collateral into the correspondent conditionals
        vm.startPrank(alice);
        uint amount = 100;
        collateralToken.approve(CT_gnosis, 2*amount);
        ICT(CT_gnosis).splitPosition(       // shallow split
            collateralToken, 
            rootCollateral, 
            condition1, 
            sets1, 
            2*amount
        );
        ICT(CT_gnosis).setApprovalForAll(distributor1, true);
        IDistributor(distributor1).configure(
            amount,
            defaultTimeOut, //_timeout
            0, //_price
            0//_fee
        );
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(2);
        alicePrediction[1] = uint(3);
        alicePrediction[2] = uint(5);
        IDistributor(distributor1).setProbabilityDistribution(0, alicePrediction, '');
        vm.warp(defaultTimeOut);
        vm.expectRevert(bytes("Time is out"));//
        IDistributor(distributor1).setProbabilityDistribution(0, alicePrediction, '');
        vm.expectRevert(bytes('Only moderators can change'));
        IDistributor(distributor1).changeTimeOut(defaultTimeOut + 1 days); 
        // change timeout via a manager
        vm.stopPrank();
        factory.grantRole(MANAGER_ROLE, alice); // only admin
        vm.startPrank(alice);
        factory.changeDistributorTimeout(distributor1, defaultTimeOut + 1 days); // dont like this
        IDistributor(distributor1).setProbabilityDistribution(0, alicePrediction, '');
        // if answered, should revert
        vm.stopPrank();
        uint[] memory payout = new uint[](3);
        payout[0] = 1;
        payout[1] = 0;
        payout[2] = 0;        
        vm.startPrank(oracle);
        ICT(CT_gnosis).reportPayouts(questionId1, payout);
        IDistributor(distributor1).checkQuestion();
        vm.stopPrank();
        vm.expectRevert(bytes('Question answered'));
        vm.prank(alice);
        IDistributor(distributor1).changeTimeOut(defaultTimeOut + 1 days); 
    }
    function test_question_answered_notChecked() public {
        distributor1 = factory.createDistributor(
            rootCollateral,
            condition1,
            address(collateralToken),
            sets1,
            0 // template index
        );
        vm.label(distributor1, "Distributor for Q1");        
        // split collateral into the correspondent conditionals
        vm.startPrank(alice);
        uint amount = 100;
        collateralToken.approve(CT_gnosis, 2*amount);
        ICT(CT_gnosis).splitPosition(       // shallow split
            collateralToken, 
            rootCollateral, 
            condition1, 
            sets1, 
            2*amount
        );
        ICT(CT_gnosis).setApprovalForAll(distributor1, true);
        IDistributor(distributor1).configure(
            amount,
            0, //_timeout
            0, //_price
            0//_fee
        );        
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(2);
        alicePrediction[1] = uint(3);
        alicePrediction[2] = uint(5);
        IDistributor(distributor1).setProbabilityDistribution(0, alicePrediction, '');
        vm.stopPrank();
        uint[] memory vals = IDistributor(distributor1).getUserPosition(alice);
        // answer question
        uint[] memory payout = new uint[](3);
        payout[0] = 1;
        payout[1] = 0;
        payout[2] = 0;
        vm.prank(oracle);
        ICT(CT_gnosis).reportPayouts(questionId1, payout);
        alicePrediction[0] = uint(1);
        alicePrediction[1] = uint(0);
        alicePrediction[2] = uint(0);
        vm.prank(alice);
        IDistributor(distributor1).setProbabilityDistribution(0, alicePrediction, '');
        // below line does not have an effect on alice position (it closes the question)
        // check contract state payout_numerator & denominator
        assertEq(IDistributor(distributor1).question_denominator(), 1);
        assertEq(IDistributor(distributor1).question_numerator(0), 1);
        assertEq(IDistributor(distributor1).question_numerator(1), 0);
        assertEq(IDistributor(distributor1).question_numerator(2), 0);
        uint[] memory vals_f = IDistributor(distributor1).getUserPosition(alice);
        assertEq(vals_f[0], vals[0]);
        assertEq(vals_f[1], vals[1]);
        assertEq(vals_f[2], vals[2]);
    }

    function test_question_answered_checked() public {
        distributor1 = factory.createDistributor(
            rootCollateral,
            condition1,
            address(collateralToken),
            sets1,
            0 // template index
        );
        vm.label(distributor1, "Distributor for Q1");        
        // split collateral into the correspondent conditionals
        vm.startPrank(alice);
        uint amount = 100;
        collateralToken.approve(CT_gnosis, 2*amount);
        ICT(CT_gnosis).splitPosition(       // shallow split
            collateralToken, 
            rootCollateral, 
            condition1, 
            sets1, 
            2*amount
        );
        ICT(CT_gnosis).setApprovalForAll(distributor1, true);
        IDistributor(distributor1).configure(
            amount,
            0, //_timeout
            0, //_price
            0//_fee
        );        
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(2);
        alicePrediction[1] = uint(3);
        alicePrediction[2] = uint(5);
        IDistributor(distributor1).setProbabilityDistribution(0, alicePrediction, '');
        vm.expectRevert(bytes('Redemption is still in the future'));
        IDistributor(distributor1).redeem();        
        vm.stopPrank();
        uint[] memory payout = new uint[](3);
        payout[0] = 1;
        payout[1] = 0;
        payout[2] = 0;
        vm.prank(oracle);
        ICT(CT_gnosis).reportPayouts(questionId1, payout);
        vm.startPrank(alice);
        IDistributor(distributor1).checkQuestion();
        vm.expectRevert(bytes("Question answered"));// reverts but without data
        IDistributor(distributor1).setProbabilityDistribution(0, alicePrediction, '');
        assertEq(IDistributor(distributor1).question_denominator(), 1);
    }    

    function test_weighted_positions() public {
        distributor1 = factory.createDistributor(
            rootCollateral,
            condition1,
            address(collateralToken),
            sets1,
            0 // template index
        );
        vm.label(distributor1, "Distributor for Q1");        
        // split collateral into the correspondent conditionals
        vm.startPrank(alice);
        uint amount = 100;
        collateralToken.approve(CT_gnosis, amount+10);
        ICT(CT_gnosis).splitPosition(       // shallow split
            collateralToken, 
            rootCollateral, 
            condition1, 
            sets1, 
            amount+10
        );
        ICT(CT_gnosis).setApprovalForAll(distributor1, true);
        IDistributor(distributor1).configure(
            10,
            0, //_timeout
            10, //_price
            0//_fee
        );        
        uint positions_0 = IDistributor(distributor1).positionIds(0);
        uint positions_1 = IDistributor(distributor1).positionIds(1);
        uint positions_2 = IDistributor(distributor1).positionIds(2);
        //////////////////////////////////////////////////  POSITIONS
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(25);
        alicePrediction[1] = uint(75);
        alicePrediction[2] = uint(0);
        IDistributor(distributor1).setProbabilityDistribution(100, alicePrediction, '');
        vm.stopPrank();
        vm.startPrank(bob);
        //collateralToken.approve(distributor1, initialBalance);        
        collateralToken.approve(CT_gnosis, amount);
        ICT(CT_gnosis).splitPosition(       // shallow split
            collateralToken, 
            rootCollateral, 
            condition1, 
            sets1, 
            50//amount
        );
        ICT(CT_gnosis).setApprovalForAll(distributor1, true);

        uint[] memory bobPrediction = new uint[](3);
        bobPrediction[0] = uint(25);
        bobPrediction[1] = uint(0);
        bobPrediction[2] = uint(75);
        IDistributor(distributor1).setProbabilityDistribution(50, bobPrediction, '');
        vm.stopPrank();
        vm.startPrank(carol);
        //collateralToken.approve(distributor1, initialBalance);        
        collateralToken.approve(CT_gnosis, amount);
        ICT(CT_gnosis).splitPosition(       // shallow split
            collateralToken, 
            rootCollateral, 
            condition1, 
            sets1, 
            10//amount
        );
        ICT(CT_gnosis).setApprovalForAll(distributor1, true);

        uint[] memory carolPrediction = new uint[](3);
        carolPrediction[0] = uint(33);
        carolPrediction[1] = uint(33);
        carolPrediction[2] = uint(33);
        IDistributor(distributor1).setProbabilityDistribution(10, carolPrediction, '');
        vm.stopPrank();
        ///////////////////////////////////////////////// ANSWER
        uint[] memory payout = new uint[](3);
        payout[0] = 1;
        payout[1] = 0;
        payout[2] = 0;
        vm.startPrank(oracle);
        ICT(CT_gnosis).reportPayouts(questionId1, payout);
        IDistributor(distributor1).checkQuestion();
        vm.stopPrank();
        //////////////////////////////////////////////// RESULTS
        uint[] memory global = IDistributor(distributor1).getProbabilityDistribution();        
        emit log_named_uint("total collateral:", IDistributor(distributor1).totalBalance());
        emit log_named_uint("GLOBAL Result 0:", uint256(global[0]));
        emit log_named_uint("GLOBAL Result 1:", uint256(global[1]));
        emit log_named_uint("GLOBAL Result 2:", uint256(global[2]));
//        emit log_string("PadIsNotLive()");
        uint[] memory Alice_returnedTokens = IDistributor(distributor1).getUserRedemption(address(alice));
        emit log_named_uint("ALICE returned 0:", uint256(Alice_returnedTokens[0]));
        emit log_named_uint("ALICE returned 1:", uint256(Alice_returnedTokens[1]));
        emit log_named_uint("ALICE returned 2:", uint256(Alice_returnedTokens[2]));

        uint[] memory Bob_returnedTokens = IDistributor(distributor1).getUserRedemption(address(bob));
        emit log_named_uint("BOB returned 0:", uint256(Bob_returnedTokens[0]));
        emit log_named_uint("BOB returned 1:", uint256(Bob_returnedTokens[1]));
        emit log_named_uint("BOB returned 2:", uint256(Bob_returnedTokens[2]));

        uint[] memory Carol_returnedTokens = IDistributor(distributor1).getUserRedemption(address(carol));
        emit log_named_uint("CAROL returned 0:", uint256(Carol_returnedTokens[0]));
        emit log_named_uint("CAROL returned 1:", uint256(Carol_returnedTokens[1]));
        emit log_named_uint("CAROL returned 2:", uint256(Carol_returnedTokens[2]));

        //////////////////////////////////////////////// REDEMPTION
        vm.prank(alice);
        IDistributor(distributor1).redeem();
        assertEq(ICT(CT_gnosis).balanceOf(address(alice), positions_0), Alice_returnedTokens[0]);
        assertEq(ICT(CT_gnosis).balanceOf(address(alice), positions_1), Alice_returnedTokens[1]);
        assertEq(ICT(CT_gnosis).balanceOf(address(alice), positions_2), Alice_returnedTokens[2]);
        vm.prank(bob);
        IDistributor(distributor1).redeem();        
        assertEq(ICT(CT_gnosis).balanceOf(address(bob), positions_0), Bob_returnedTokens[0]);
        assertEq(ICT(CT_gnosis).balanceOf(address(bob), positions_1), Bob_returnedTokens[1]);
        assertEq(ICT(CT_gnosis).balanceOf(address(bob), positions_2), Bob_returnedTokens[2]);
        vm.prank(carol);
        IDistributor(distributor1).redeem();        
        assertEq(ICT(CT_gnosis).balanceOf(address(carol), positions_0), Carol_returnedTokens[0]);
        assertEq(ICT(CT_gnosis).balanceOf(address(carol), positions_1), Carol_returnedTokens[1]);
        assertEq(ICT(CT_gnosis).balanceOf(address(carol), positions_2), Carol_returnedTokens[2]);        
        //////////////////////////////////////////////// GETTING COLLATERAL
        bytes32 condition = ICT(CT_gnosis).getConditionId(oracle, questionId1, 3);
        userRedeemsCollateral(alice, condition, sets1);
        userRedeemsCollateral(bob, condition, sets1);
        userRedeemsCollateral(carol, condition, sets1);        
    }

    function test_mixed() public {
        // we will create a mixed conditional for 
        // Q1::A[Q2::Hi, Q2::Lo]
        bytes32 collectionA = ICT(CT_gnosis).getCollectionId(
            rootCollateral, // from collateral
            condition1,     // Q1
            sets1[0]        // A
        );
        distributor1 = factory.createDistributor(
            collectionA,
            condition2,
            address(collateralToken),
            sets2,
            0 // template index
        );
        vm.label(distributor1, "Distributor for Q1::A[Q2::Hi, Q2::Lo]");
        // split collateral into the correspondent conditionals (Q1[A, B, C])
        vm.startPrank(alice);
        uint amount = 100;
        collateralToken.approve(CT_gnosis, amount);
        // collateral into Q1[A,B,C]
        ICT(CT_gnosis).splitPosition(       // shallow split
            collateralToken, 
            rootCollateral, 
            condition1,
            sets1, 
            amount
        );
        // Q1::A into Q1::A[Hi, Lo]
        ICT(CT_gnosis).splitPosition(       // shallow split
            collateralToken, 
            collectionA,
            condition2,
            sets2, 
            amount
        );
        ICT(CT_gnosis).setApprovalForAll(distributor1, true);
        IDistributor(distributor1).configure(
            amount,
            0, //_timeout
            0, //_price
            0//_fee
        );
        vm.stopPrank();        
        uint[] memory bobPrediction = new uint[](2);
        bobPrediction[0] = uint(3);
        bobPrediction[1] = uint(7);
        vm.startPrank(bob);
        collateralToken.approve(CT_gnosis, amount);
        ICT(CT_gnosis).splitPosition(       // shallow split
            collateralToken, 
            rootCollateral, 
            condition1, 
            sets1, 
            amount
        );
        ICT(CT_gnosis).splitPosition(       // shallow split
            collateralToken, 
            collectionA, 
            condition2, 
            sets2, 
            amount
        );
        ICT(CT_gnosis).setApprovalForAll(distributor1, true);
        IDistributor(distributor1).setProbabilityDistribution(amount, bobPrediction, 'A long string to test storage issues');
        // *10 comes from a proportion given in the distributor
        uint[] memory bobPosition = IDistributor(distributor1).getUserPosition(bob);
        assertEq(bobPrediction[0]*10, bobPosition[0]);
        assertEq(bobPrediction[1]*10, bobPosition[1]);    
        // check totalBalance
        assertEq(IDistributor(distributor1).totalBalance(), 2*amount);
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
