// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/ICT.sol";
import "../interfaces/User.sol";
import "../src/SimpleDistributor.sol";
import "../src/SimpleDistributorFactory.sol";
import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
/* import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol"; */
import "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

// TODO
// test factory to deploy for boost
// problem on initialization of distributors

contract SimpleDistributorFactoryTest is Test, ERC1155Holder {

    address CT_gnosis = 0xCeAfDD6bc0bEF976fdCd1112955828E00543c0Ce; 
    bytes32 rootCollateral = 0x0000000000000000000000000000000000000000000000000000000000000000; 
    bytes32 questionId1 = 0x0000000000000000000000000000000000000000000000000000000000000001;
    
    mapping(bytes32 => bytes32) conditionsIds;
    uint256 constant PRECISION = 1e18;
    uint initialBalance = 100 * PRECISION;

    address[] public addresses;            // for balance checks
    uint[] public positions;            // subId ERC1155

    uint defaultTimeOut = block.timestamp + 1 days;

    SimpleDistributor distributor;
    SimpleDistributorFactory factory;
    User oracle;
    User alice;
    ERC20PresetMinterPauser collateralToken;

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
        factory = new SimpleDistributorFactory(address(distributor));
    }
    function prepareNewCondition(bytes32 questionId, uint responses) internal returns (bytes32 conditionId) {
        ICT(CT_gnosis).prepareCondition(address(oracle), questionId, responses);
        conditionId = ICT(CT_gnosis).getConditionId(address(oracle), questionId, responses);
        conditionsIds[questionId] = conditionId;
        return conditionId;
        emit log_named_bytes32('Condition created', conditionId);
    }

        // to test 
        // initialize markets
        // change template
        // get market's addresses

    function test_createDistributor() public {
        factory.createDistributor();        
    }
    function test_createAndInitializeDistributor() public {
        uint[] memory indexSets = new uint[](3);
        indexSets[0] = uint(1); //0b001        
        indexSets[1] = uint(2); //0b010       
        indexSets[2] = uint(4); //0b100       
        address newDistributor = factory.createDistributor();
        bytes32 conditionId = prepareNewCondition(questionId1, indexSets.length);        
        collateralToken.transfer(newDistributor, 10 * PRECISION);
        //assertEq(SimpleDistributor(newDistributor).ctAddress(), address(0));
        SimpleDistributor(newDistributor).initialize(
            conditionId,
            rootCollateral,
            address(collateralToken),
            CT_gnosis,
            indexSets,
            10 * PRECISION,
            0
        );
        assertEq(factory.getDistributorAddress(0), newDistributor);
    }
    function test_changeTemplate() public {
        factory.changeTemplate(address(0));
    }

}
