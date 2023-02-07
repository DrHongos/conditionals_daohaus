// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ICT.sol";
import "../interfaces/IDistributor.sol"; // careful here.. initialization should be shared amongst all templates

contract DistributorFactory is AccessControl {
    address public template;
    address CT_CONTRACT;
    address opinologos;
//    bytes32 ROOT_PARENT_COLLECTION = 0x0000000000000000000000000000000000000000000000000000000000000000;

    struct Distributor {
        bytes32 collection;
        bytes32 question_condition;
        address template;
        uint price;
    }
    mapping(bytes32 => bool) public distributorsSignatures;
    mapping(address => Distributor) public distributors;
    uint public distributorsCount;

/*      
        bytes32 conditionalParentCollection,           
        bytes32 conditionalCondition,               
        uint conditionalIndex,                       
        address templateUsed, 
        */
    event DistributorCreated(
        bytes32[] conditions,
        uint[] conditionsIndexes,
        address distributorAddress,
        uint price,
        uint[] indexSets
    );
    event DistributorTemplateChanged(address newTemplate);

    constructor(address _CT_CONTRACT, address _opinologos) {
        CT_CONTRACT = _CT_CONTRACT;
        opinologos = _opinologos;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function createDistributor( 
        bytes32[] calldata _conditions,
        uint[] calldata _conditionsIndexes,
        //bytes32 conditionalParentCollection,        // quiza deprecar
        //bytes32 conditionalCondition,               // quiza deba ser array
        //uint conditionalIndex,                      // este tambien
        //bytes32 _question_condition,  // question condition // deprecar y usar conditions[last]
        address _collateralToken, // token of the parent collection
        uint _price,
        uint[] calldata _indexSets // groups for outcomes
    )
        external
        returns (address newDistributorAddress)
    {    
        bytes32 last_condition = _conditions[_conditions.length - 1];    
        {
            require(ICT(CT_CONTRACT).payoutDenominator(last_condition) == 0, "Question closed");
            uint outcomeSlotCount = ICT(CT_CONTRACT).getOutcomeSlotCount(last_condition);
            uint fullIndexSet = (1 << outcomeSlotCount) - 1;
            uint result = 0;
            for (uint256 i = 0; i < _indexSets.length; i++) {
                result += _indexSets[i];
            }
            require(result == fullIndexSet, "Invalid indexSets");
            // could also check that conditionalIndex < fullIndex(ICT(CT_CONTRACT).getOutcomeSlotCount(conditionalCondition))
            // TODO: can check the timeout of both questions and allow/block its creation
            require(template != address(0), "Template empty");
        }

        // esto se modifica, pues conditions puede tener mas de una pregunta
        bytes32 parentCollection;
        if (_conditions.length > 1) {
            bytes32 collection = bytes32(0);
            for (uint i = 0; i < _conditions.length - 1; i++) {
                collection = ICT(CT_CONTRACT).getCollectionId(collection, _conditions[i], _conditionsIndexes[i]);
            }
            parentCollection= collection;
        } else {
            parentCollection = bytes32(0);  // ROOT
        }
        bytes32 signature = keccak256(abi.encodePacked(parentCollection, last_condition, _price, _indexSets));
        require(distributorsSignatures[signature] == false, "Distributor already exists");
        distributorsSignatures[signature] = true;
        ////////////

        newDistributorAddress = Clones.clone(template);
        Distributor memory newDistributor = Distributor({
            collection: parentCollection,
            question_condition: last_condition,
            template: template,
            price: _price
        });
        distributors[newDistributorAddress] = newDistributor;

        IDistributor(newDistributorAddress).initialize(
            _conditions,
            _conditionsIndexes,
            opinologos,
            _collateralToken,
            _price,
            _indexSets
        );

        distributorsCount += 1;
        emit DistributorCreated(
            //conditionalParentCollection,           
            _conditions,               
            _conditionsIndexes,                      
            newDistributorAddress, 
//            template,
            _price,
            _indexSets
        );
    }

    function distributorParent(address dist) public view returns(bytes32) {
        Distributor memory obj = distributors[dist];
        return obj.collection;        
    }

    function setTemplate(address _newTemplate)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        template = _newTemplate;
        emit DistributorTemplateChanged(_newTemplate);
    }    



}