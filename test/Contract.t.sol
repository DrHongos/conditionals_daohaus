// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../interfaces/ICT.sol";
import "../interfaces/User.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
// ERC20

// Environment set to test conditional tokens in gnosis chain
// forge test --fork-url https://rpc.gnosischain.com
// Later create contracts for:
// games, governance, prediction markets, etc

contract ContractTest is Test, ERC1155Holder {

    address CT_gnosis = 0xCeAfDD6bc0bEF976fdCd1112955828E00543c0Ce;
    // then check markets

    bytes32 rootCollateral = 0x0000000000000000000000000000000000000000000000000000000000000000; 
    bytes32 questionId1 = 0x0000000000000000000000000000000000000000000000000000000000000001;
    bytes32 questionId2 = 0x0000000000000000000000000000000000000000000000000000000000000002;
    bytes32 questionId3 = 0x0000000000000000000000000000000000000000000000000000000000000003;

    mapping(bytes32 => bytes32) conditionsIds;

    uint256 constant PRECISION = 1e18;
    uint initialBalance = 100 * PRECISION;
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
        collateralToken.mint(address(alice), initialBalance);
        collateralToken.mint(address(bob), initialBalance);
        collateralToken.mint(address(carol), initialBalance);
        collateralToken.mint(address(deedee), initialBalance);
    }

    function prepareNewCondition(bytes32 questionId1, uint responses) internal {
        ICT(CT_gnosis).prepareCondition(address(oracle), questionId1, responses);
        bytes32 conditionId = ICT(CT_gnosis).getConditionId(address(oracle), questionId1, responses);
        conditionsIds[questionId1] = conditionId;
        emit log_named_bytes32('Condition created', conditionId);
    }
    // create function to check all indexSets, maybe get total balancesº of a conditionId

    function test_prepareCondition() public {
        prepareNewCondition(questionId1, 2);
        assertEq(ICT(CT_gnosis).getOutcomeSlotCount(conditionsIds[questionId1]), 2);
    }
    mapping(uint => bytes32) collectionsIds;
    mapping(uint => uint256) positionsIds;
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

    uint256[] public indexes;
    address[] public addresses;
    uint256[] public positions;

    function test_splitCondition() public {
        // should i test fuzz on forked networks?
        uint amountToSplit = 10 * PRECISION;
        
        prepareNewCondition(questionId1, 2);
        collateralToken.approve(CT_gnosis, initialBalance);        

        uint[] memory collectionIndexSet = new uint[](2);
        collectionIndexSet[0] = uint(1); // Option A 
        collectionIndexSet[1] = uint(2); // Option B 
        for (uint i=0; i < 2; i++) {
            (bytes32 condition, uint position) = getCollectionAndPosition(
                address(collateralToken),
                rootCollateral,
                conditionsIds[questionId1],
                collectionIndexSet[i]
            );
            addresses.push(address(this));
            positions.push(position);
        }
        ICT(CT_gnosis).splitPosition(
            collateralToken,
            rootCollateral,
            conditionsIds[questionId1],
            collectionIndexSet,
            amountToSplit
        );
        uint[] memory balance = ICT(CT_gnosis).balanceOfBatch(
            addresses,
            positions
        );
        assertEq(balance[0], amountToSplit);
        assertEq(balance[0], balance[1]);
    }

    function test_redeemPositions() public {
        uint amountToSplit = 30 * PRECISION;
        uint possibleOutcomes = 3;
        prepareNewCondition(questionId1, possibleOutcomes);
        collateralToken.approve(CT_gnosis, initialBalance);        
        uint[] memory collectionIndexSet = new uint[](possibleOutcomes);
        collectionIndexSet[0] = 1; // Option A 
        collectionIndexSet[1] = 2; // Option B 
        collectionIndexSet[2] = 4; // Option B 
        for (uint i=0; i < possibleOutcomes; i++) {
            (bytes32 condition, uint position) = getCollectionAndPosition(
                address(collateralToken),
                rootCollateral,
                conditionsIds[questionId1],
                collectionIndexSet[i]
            );
            indexes.push(i);
            addresses.push(address(alice));
            positions.push(position);
        }
        ICT(CT_gnosis).splitPosition(
            collateralToken,
            rootCollateral,
            conditionsIds[questionId1],
            collectionIndexSet,
            amountToSplit
        );
        // transfer to different players
            // partial (check THE ISSUE)
        uint[] memory alicePrediction = new uint[](3);
        alicePrediction[0] = uint(2 * PRECISION); // 20% option A
        alicePrediction[1] = uint(3 * PRECISION); // 030% option B
        alicePrediction[2] = uint(5 * PRECISION); // 50% option C
        //uint[] bobPrediction = [70,20,10];
        uint[] memory bobPrediction = new uint[](3);
        bobPrediction[0] = uint(7 * PRECISION);
        bobPrediction[1] = uint(2 * PRECISION);
        bobPrediction[2] = uint(1 * PRECISION);
        //uint[] carolPrediction = [25,50,25];        
        uint[] memory carolPrediction = new uint[](3);
        carolPrediction[0] = uint(25  * PRECISION /10);
        carolPrediction[1] = uint(5  * PRECISION);
        carolPrediction[2] = uint(25  * PRECISION /10);

        ICT(CT_gnosis).safeBatchTransferFrom(
            address(this),
            address(alice),
            positions,
            alicePrediction,
            '0x'
        );
        uint[] memory balance = ICT(CT_gnosis).balanceOfBatch(
            addresses, // alice
            positions
        );
        ICT(CT_gnosis).safeBatchTransferFrom(
            address(this),
            address(bob),
            positions,
            bobPrediction,
            '0x'
        );
        ICT(CT_gnosis).safeBatchTransferFrom(
            address(this),
            address(carol),
            positions,
            carolPrediction,
            '0x'
        );
            // total
        //----------------
        assertEq(balance[0], alicePrediction[0]);
        assertEq(balance[1], alicePrediction[1]);
        assertEq(balance[2], alicePrediction[2]);

        // report payout
        uint[] memory payouts = new uint[](3);
        payouts[0] = 1;
        payouts[1] = 0;
        payouts[2] = 0;
        oracle.reportPayouts(
            CT_gnosis,
            questionId1,
            payouts
        );
        emit log_string('Answer set!');
        uint alicePrevBalance = collateralToken.balanceOf(address(alice));
        // redeemPositions and check balances
        alice.redeemPositions(
            CT_gnosis,
            rootCollateral,// parentCollectionId
            conditionsIds[questionId1],
            collectionIndexSet
        );
        bob.redeemPositions(
            CT_gnosis,
            rootCollateral,// parentCollectionId
            conditionsIds[questionId1],
            collectionIndexSet
        );
        carol.redeemPositions(
            CT_gnosis,
            rootCollateral,// parentCollectionId
            conditionsIds[questionId1],
            collectionIndexSet
        );

        assertGt(collateralToken.balanceOf(address(alice)), alicePrevBalance);
        assertGt(collateralToken.balanceOf(address(bob)), collateralToken.balanceOf(address(alice)));
        assertGt(collateralToken.balanceOf(address(bob)), collateralToken.balanceOf(address(carol)));
        assertGt(collateralToken.balanceOf(address(carol)), collateralToken.balanceOf(address(alice)));
        
        uint thisBalance = collateralToken.balanceOf(address(this));
        assertEq(thisBalance, initialBalance - amountToSplit);
    }

    function test_burnBySplit() public {}

//////////--------------
    function test_deepPositions() public {}
    function test_redeem_deepPositions() public {}
    function test_distributions() public {}
    // create models and specific test files for each 


}
