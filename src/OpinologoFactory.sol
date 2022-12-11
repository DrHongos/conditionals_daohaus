// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ICT.sol";
import "../interfaces/IDistributor.sol"; // careful here.. initialization should be shared amongst all templates (?)
//import "../interfaces/IDistributor.sol"; // careful here.. initialization should be shared amongst all templates (?)

//  TODO


contract OpinologosFactory is AccessControl {
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
    address CT_CONTRACT; // set in constructor

    struct Distributor {
        bytes32 collection;
        bytes32 question_condition;
        address template;
        // maybe add the positions?
    }
    mapping(address => Distributor) public distributors;

    struct Question {
        bytes32 condition;        
        bytes32 questionId;
        address creator;
        address oracle; 
        uint outcomes;
    }
    mapping(bytes32 => Question) public questions;    
    
    mapping(uint => address) public templates;
    uint public questionsCount;
    uint public distributorsCount;

    event NewQuestionCreated(
        address oracle, 
        address creator, 
        bytes32 condition, 
        bytes32 questionId, 
        uint outcomes, 
        uint index
    );
    event DistributorCreated(
        address distributorAddress,
        bytes32 question_condition, 
        address templateUsed, 
        uint distributorIndex
    );
    event DistributorTemplateChanged(address newTemplate, uint index);

    constructor(address _CT_CONTRACT) {
        CT_CONTRACT = _CT_CONTRACT;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CREATOR_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    ///@dev creates a new condition and stores it
    function createQuestion(
        address _oracle,         // solver of the condition
        bytes32 _questionId,     // referrer to the condition (used to store IPFS cid of question data)
        uint _responses          // number of possible outcomes
    ) public onlyRole(CREATOR_ROLE) returns (bytes32 conditionId) {
        address _creator = msg.sender;
        ICT(CT_CONTRACT).prepareCondition(address(_oracle), _questionId, _responses);
        conditionId = ICT(CT_CONTRACT).getConditionId(address(_oracle), _questionId, _responses);
        Question memory newQuestion = Question({
            condition: conditionId,        
            questionId: _questionId,
            creator: _creator,
            oracle: _oracle, 
            outcomes: _responses
        });
        questions[conditionId] = newQuestion;
        questionsCount++;
        emit NewQuestionCreated(_oracle, _creator, conditionId, _questionId, _responses, questionsCount);
    }

//        onlyRole(CREATOR_ROLE)
    function createDistributor(
        bytes32 _parentCollection, // frontend managed
        bytes32 _question_condition,  // question condition
        address _collateralToken, // token of the distributor
        uint[] calldata _indexSets, // groups for outcomes
        uint template_index // template index
    )
        external
        returns (address newDistributorAddress)
    {
// NOTICE!! the test below is blocked for test issues.
// require(ICT(CT_CONTRACT).payoutDenominator(questions[_question_index].condition) != 0, "Question closed");
        address templateUsed = templates[template_index];
        require(templateUsed != address(0), "Template empty");

        newDistributorAddress = Clones.clone(templateUsed);
        Distributor memory newDistributor = Distributor({
            collection: _parentCollection,
            question_condition: _question_condition,        
            template: templateUsed
            //contract_address: newDistributorAddress,
        });
        distributors[newDistributorAddress] = newDistributor;

        // TODO: this should be a general implementation of the initialize function
        IDistributor(newDistributorAddress).initialize(
            _question_condition,
            _parentCollection,
            _collateralToken,
            _indexSets
        );

        distributorsCount += 1;
        emit DistributorCreated(
            newDistributorAddress, 
            _question_condition,
            templateUsed,
            distributorsCount
        );
    }

    function setTemplate(address _newTemplate, uint index)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        templates[index] = _newTemplate;
        emit DistributorTemplateChanged(_newTemplate, index);
    }

    ///////////////////////////////////////////////////VIEW FUNCTIONS
    // candidate to deprecation (only used in tests)
    function getParentCollection(address dist) external view returns(bytes32) {
        return distributors[dist].collection;
    }

}
