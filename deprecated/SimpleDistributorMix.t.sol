
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

contract SimpleDistributorMix is Test, ERC1155Holder {

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

    OpinologosFactory factory;
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
        ////////////////////////////////// QUESTIONS
        bytes32 condition_created = factory.createQuestion(oracle, questionId1, 3);
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100
        vm.prank(alice);
        distributor_address = factory.createDistributor(
            rootCollateral,
            condition_created,
            address(collateralToken),
            indexSets,
            0 // template index
        );                 
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

    function test_mixed_distributors() public {
        // create another question, mix w the first and launch a distributor for it
        uint amount = 1000;
        bytes32 condition1 = ICT(CT_gnosis).getConditionId(oracle, questionId1, 3);
        bytes32 condition2 = factory.createQuestion(oracle, questionId2, 2);
        uint[] memory sets_q1 = new uint[](3);
        sets_q1[0] = uint(1); //0b001        
        sets_q1[1] = uint(2); //0b010       
        sets_q1[2] = uint(4); //0b100
        vm.startPrank(alice);
        collateralToken.approve(CT_gnosis, amount);
        // gets evenly distributed parent tokens (q1 ct's)
        ICT(CT_gnosis).splitPosition(
            collateralToken,
            rootCollateral, 
            condition1,
            sets_q1,
            amount
        );

        (bytes32 collection1_1, uint position1_1) = getCollectionAndPosition(
            address(collateralToken), 
            rootCollateral, 
            condition1, 
            1
        );

        uint[] memory sets_q2 = new uint[](2);
        sets_q2[0] = uint(1); //0b01
        sets_q2[1] = uint(2); //0b10       

        // splits in a deeper level (collection 1 / position 1 with q2)
        ICT(CT_gnosis).splitPosition(
            collateralToken,
            collection1_1,
            condition2,
            sets_q2,
            amount
        );

        for (uint i = 0; i < sets_q2.length; i++) {
            (bytes32 collection1_2, uint position1_2) = getCollectionAndPosition(
                address(collateralToken), 
                collection1_1,
                condition2, 
                sets_q2[i]
            );
            emit log_named_uint("for Q1/Q2:", i);
            emit log_named_bytes32("collection: ", collection1_2);
            emit log_named_uint("position: ", position1_2);
        }
        (bytes32 collection2_1, uint position2_1) = getCollectionAndPosition(
            address(collateralToken), 
            rootCollateral, 
            condition2, 
            1
        );

        for (uint i = 0; i < sets_q1.length; i++) {
            (bytes32 collection2_2, uint position2_2) = getCollectionAndPosition(
                address(collateralToken), 
                collection2_1,
                condition1, 
                sets_q1[i]
            );
            emit log_named_uint("for Q2/Q1:", i);
            emit log_named_bytes32("collection: ", collection2_2);
            emit log_named_uint("position: ", position2_2);
        }

       vm.stopPrank();
 
    }

    function test_split_multiple() public {
        uint amount = 1000;
        bytes32 condition1 = ICT(CT_gnosis).getConditionId(oracle, questionId1, 3);
        bytes32 condition2 = factory.createQuestion(oracle, questionId2, 2);
        uint[] memory sets_q1 = new uint[](3);
        sets_q1[0] = uint(1); //0b001        
        sets_q1[1] = uint(2); //0b010       
        sets_q1[2] = uint(4); //0b100
        vm.startPrank(alice);
        collateralToken.approve(CT_gnosis, amount);
        // gets evenly distributed parent tokens (q1 ct's)
        ICT(CT_gnosis).splitPosition(
            collateralToken,
            rootCollateral, 
            condition1,
            sets_q1,
            amount
        );
        uint[] memory sets_q2 = new uint[](2);
        sets_q2[0] = uint(1); //0b01
        sets_q2[1] = uint(2); //0b10       
       
        uint[] memory positions = new uint[](6);
        address[] memory addresses = new address[](6);
        uint ind = 0;
        for (uint i = 0; i<sets_q1.length; i++) {
            bytes32 collection = ICT(CT_gnosis).getCollectionId(
                rootCollateral, 
                condition1, 
                sets_q1[i]
            );
            ICT(CT_gnosis).splitPosition(
                collateralToken,
                collection, 
                condition2,
                sets_q2,
                amount
            );

            for (uint j=0; j<sets_q2.length; j++) {
                bytes32 collectionId = ICT(CT_gnosis).getCollectionId(
                    collection,
                    condition2,
                    sets_q2[j]
                );
                uint positionId = ICT(CT_gnosis).getPositionId(
                    address(collateralToken),
                    collectionId
                );
                positions[ind] = positionId;
                addresses[ind] = alice;
                ind++;
            }
        }
        uint[] memory balances = ICT(CT_gnosis).balanceOfBatch(addresses, positions);
        for (uint i = 0; i<6; i++) {
            assertEq(balances[i], amount);
            emit log_named_uint("balance mixed", balances[i]);
        }
    }



}