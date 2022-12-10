// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/ICT.sol";
import "../src/Distributor.sol";
import "../interfaces/IDistributor.sol";
import "../src/OpinologoFactory.sol";
import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";


// TODO: 
/* 
    roles
    configs

*/


contract DistributorFactoryTest is Test, ERC1155Holder {

    address CT_gnosis = 0xCeAfDD6bc0bEF976fdCd1112955828E00543c0Ce; 
    bytes32 rootCollateral = 0x0000000000000000000000000000000000000000000000000000000000000000; 
    bytes32 questionId1 = 0x0000000000000000000000000000000000000000000000000000000000000001;
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");

    mapping(bytes32 => bytes32) conditionsIds;
    uint256 constant PRECISION = 1e18;
    uint initialBalance = 100 * PRECISION;

    address[] public addresses;            // for balance checks
    uint[] public positions;            // subId ERC1155

    uint defaultTimeOut = block.timestamp + 1 days;

    Distributor distributor;
    OpinologosFactory factory;
    address oracle;
    address alice;
    ERC20PresetMinterPauser collateralToken;

    struct Question {
        bytes32 condition;        
        bytes32 questionId; // in doubt
        address creator;    //     "
        address oracle;     //     "
        uint outcomes;
        //mapping(uint => Collection) collections;
        // uint collectionsCount;
    }

    function setUp() public {
        vm.label(address(this), "Test Contract");
        collateralToken = new ERC20PresetMinterPauser("FakeUSD", "FUSD");
        vm.label(address(collateralToken), "Token Contract");
        //oracle = new User(address(collateralToken));
        oracle = address(0);
        vm.label(address(oracle), "Oracle");
        //alice = new User(address(collateralToken));
        alice = address(1);
        vm.label(address(alice), "Alice");
        collateralToken.mint(address(this), initialBalance);        
        collateralToken.mint(address(alice), initialBalance);        
        distributor = new Distributor();
        vm.label(address(distributor), "Distributor template");
        factory = new OpinologosFactory(CT_gnosis);
        vm.label(address(factory), "Factory");
        factory.grantRole(CREATOR_ROLE, address(this));
    }
    function test_prepareNewCondition() public {
        assertEq(factory.questionsCount(), 0);
        bytes32 condition_created = factory.createQuestion(address(oracle), questionId1, 3);
        assertEq(factory.questionsCount(), 1);
        (bytes32 cond, bytes32 quest, address creator, address _oracle, uint outcomes) = factory.questions(condition_created);
        assertEq(cond, condition_created);
        assertEq(_oracle, oracle);
        assertEq(outcomes, 3);
        assertEq(quest, questionId1);
    } 
    function test_createDistributor() public {
        assertEq(factory.distributorsCount(), 0);
        bytes32 condition_created = factory.createQuestion(address(oracle), questionId1, 3);
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100
        factory.setTemplate(address(distributor), 0);        
        vm.prank(alice);
        address distributor_address = factory.createDistributor(
            rootCollateral,
            condition_created,
            address(collateralToken),
            indexSets,
            0 // template index
        );
        assertEq(factory.distributorsCount(), 1);
        (bytes32 collection, bytes32 question_condition, address template)
            = factory.distributors(distributor_address);
        assertEq(collection, rootCollateral);
        assertEq(template, factory.templates(0));
        assertEq(question_condition, condition_created);
        (bytes32 cond, bytes32 questionId, address creator, address _oracle, uint outcomes) = factory.questions(question_condition);
        assertEq(questionId1, questionId);
    } 
    function test_createAndInitializeDistributor() public {
        bytes32 condition1 = factory.createQuestion(address(oracle), questionId1, 3);
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100
        factory.setTemplate(address(distributor), 0);
        address distributor1 = factory.createDistributor(
            rootCollateral,
            condition1,
            address(collateralToken),
            indexSets,
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
            indexSets, 
            amount
        );
        ICT(CT_gnosis).setApprovalForAll(distributor1, true);
        IDistributor(distributor1).configure(
            amount,
            1, //timeOut (no limit)
            2, //price
            3 //fee
        );
        vm.stopPrank();        

        assertEq(IDistributor(distributor1).price(), 2);
        assertEq(IDistributor(distributor1).fee(), 3);
        assertEq(IDistributor(distributor1).timeout(), 1);
    }

//    function test_creator_prepareNewCondition() public {} // create factoryUser.sol
//    function testFail_anyone_prepareNewCondition() public {}
//    function test_set_templates() public {}

}
