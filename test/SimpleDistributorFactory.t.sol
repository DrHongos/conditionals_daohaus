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

contract SimpleDistributorFactoryTest is Test, ERC1155Holder {

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

    SimpleDistributor distributor;
    QuestionsFactory factory;
    User oracle;
    User alice;
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
        oracle = new User(address(collateralToken));
        vm.label(address(oracle), "Oracle");
        alice = new User(address(collateralToken));
        vm.label(address(alice), "Alice");
        collateralToken.mint(address(this), initialBalance);        
        collateralToken.mint(address(alice), initialBalance);        
        distributor = new SimpleDistributor();
        vm.label(address(distributor), "Distributor template");
        factory = new QuestionsFactory(CT_gnosis);
        vm.label(address(factory), "Factory");
        factory.grantRole(CREATOR_ROLE, address(this));
    }
    function test_prepareNewCondition() public {
        assertEq(factory.questionsCount(), 0);
        bytes32 condition_created = factory.createQuestion(address(oracle), questionId1, 3);
        assertEq(factory.questionsCount(), 1);
        (bytes32 cond, bytes32 quest, address creator, address _oracle, uint outcomes) = factory.questions(0);
        assertEq(cond, condition_created);
        assertEq(_oracle, address(oracle));
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
        alice.createDistributor(
            address(factory),
            rootCollateral,
            address(collateralToken),
            indexSets,
            0, // template index
            0  // question index
        );
        assertEq(factory.distributorsCount(), 1);
        (bytes32 collection, address contract_address, address template, uint question_index)
            = factory.distributors(0);
        assertEq(collection, rootCollateral);
        assertEq(contract_address, factory.getDistributorAddress(0));
        assertEq(template, factory.templates(0));
        assertEq(question_index, 0);
        address distributor = factory.getDistributorAddress(0);
        vm.label(distributor, "Distributor");
//        assertTrue(ISimpleDistributor(distributor).hasRole(MANAGER_ROLE, address(factory)));
//        assertTrue(ISimpleDistributor(distributor).hasRole(MANAGER_ROLE, address(alice)));
        // not the user! :D
        // need to create functions from the factory to grant/revoke roles
        // also to modify stage
        //assertTrue(ISimpleDistributor(factory.getDistributorAddress(0)).hasRole(DEFAULT_ADMIN_ROLE, address(factory)));
        // fails, so i will test
        //ISimpleDistributor(distributor).revokeRole(MANAGER_ROLE, address(alice));
        //assertTrue(!ISimpleDistributor(distributor).hasRole(MANAGER_ROLE, address(alice)));

    } 
   
    function test_createAndInitializeDistributor() public {
        bytes32 condition_created = factory.createQuestion(address(oracle), questionId1, 3);
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100
        factory.setTemplate(address(distributor), 0);
        alice.createDistributor(
            address(factory),
            rootCollateral,
            address(collateralToken),
            indexSets,
            0, // template index
            0  // question index
        );        
        address distributor = factory.getDistributorAddress(0);
        vm.label(distributor, "Distributor");
//        assertEq(ISimpleDistributor(distributor).status(), 0);
        uint initial_amount = 10000; 
        alice.approveCollateral(distributor, initial_amount);
        alice.configure(
            factory.getDistributorAddress(0),
            initial_amount, //amountToSplit
            1, //timeOut (no limit)
            2, //price
            3 //fee
        );
//        assertEq(ISimpleDistributor(distributor).status(), 1);
        assertEq(ISimpleDistributor(distributor).price(), 2);
        assertEq(ISimpleDistributor(distributor).fee(), 3);
        assertEq(ISimpleDistributor(distributor).timeout(), 1);
    }

//    function test_creator_prepareNewCondition() public {} // create factoryUser.sol
//    function testFail_anyone_prepareNewCondition() public {}
//    function test_set_templates() public {}

}
