// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ICT.sol";
import "../interfaces/IDistributor.sol"; // careful here.. initialization should be shared amongst all templates

//  TODO
// questions have timelock (distributors are conditioned on it)
    // conditional distributors could be conditioned by question timelock (only if ends later than parent)
// oracle approves question (address can be changed)
// fee mechanism

contract OpinologosFactory is AccessControl {
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
    address CT_CONTRACT; // set in constructor
    uint public fee;
    struct Distributor {
        bytes32 collection;
        bytes32 question_condition;
        address template;
    }
    mapping(bytes32 => bool) public distributorsSignatures;
    mapping(address => Distributor) public distributors;
    struct Question {
        bytes32 condition;        
        bytes32 questionId;
        address creator;
        address oracle; 
        uint outcomes;
        uint timeout;        // time constraint
        //bool approved;        // oracle approval
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
        uint timeout,
        uint index
    );
    event DistributorCreated(
        bytes32 conditionalParentCollection,           
        bytes32 conditionalCondition,               
        uint conditionalIndex,                      
        address distributorAddress,
        address templateUsed, 
        uint[] indexSets
    );

    event DistributorTemplateChanged(address newTemplate, uint index);
    event FeeUpdated(uint _newFee);
    event TimeOutUpdated(bytes32 question_condition, uint timeout);
    
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
        uint _responses,          // number of possible outcomes
        uint _timeout
    ) public onlyRole(CREATOR_ROLE) returns (bytes32 conditionId) {
        address _creator = msg.sender;
        ICT(CT_CONTRACT).prepareCondition(address(_oracle), _questionId, _responses);
        conditionId = ICT(CT_CONTRACT).getConditionId(address(_oracle), _questionId, _responses);
        Question memory newQuestion = Question({
            condition: conditionId,        
            questionId: _questionId,
            creator: _creator,
            oracle: _oracle, 
            outcomes: _responses,
            timeout: _timeout
        });
        questions[conditionId] = newQuestion;
        questionsCount++;
        emit NewQuestionCreated(_oracle, _creator, conditionId, _questionId, _responses, _timeout, questionsCount);
    }

    function createDistributor(
        bytes32 conditionalParentCollection,           
        bytes32 conditionalCondition,               
        uint conditionalIndex,                      
        bytes32 _question_condition,  // question condition
        address _collateralToken, // token of the parent collection
        uint[] calldata _indexSets, // groups for outcomes
        uint template_index // template index
    )
        external
        returns (address newDistributorAddress)
    {
// NOTICE!! the test below is blocked for test issues.
        require(ICT(CT_CONTRACT).payoutDenominator(_question_condition) == 0, "Question closed");
        address templateUsed = templates[template_index];
        require(templateUsed != address(0), "Template empty");

        bytes32 parentCollection;
        if (conditionalCondition != bytes32(0)) {
            parentCollection= ICT(CT_CONTRACT).getCollectionId(conditionalParentCollection, conditionalCondition, conditionalIndex);
        } else {
            parentCollection = bytes32(0);  // ROOT
        }

        // TODO: can check the timeout of both questions and allow/block its creation

        bytes32 signature = keccak256(abi.encodePacked(parentCollection, _question_condition, _indexSets));
        require(distributorsSignatures[signature] == false, "Distributor already exists");
        distributorsSignatures[signature] = true;
        
        newDistributorAddress = Clones.clone(templateUsed);
        Distributor memory newDistributor = Distributor({
            collection: parentCollection,
            question_condition: _question_condition,
            template: templateUsed
        });
        distributors[newDistributorAddress] = newDistributor;

        // TODO: this should be a general implementation of the initialize function
        IDistributor(newDistributorAddress).initialize(
            _question_condition,
            parentCollection,
            _collateralToken,
            _indexSets
        );

        distributorsCount += 1;
        emit DistributorCreated(
            conditionalParentCollection,           
            conditionalCondition,               
            conditionalIndex,                      
            newDistributorAddress, 
            templateUsed,
            _indexSets
        );
    }

    function setTemplate(address _newTemplate, uint index)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        templates[index] = _newTemplate;
        emit DistributorTemplateChanged(_newTemplate, index);
    }    
    function setFee(uint _newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        fee = _newFee;
        emit FeeUpdated(_newFee);
    }
    function changeTimeOut(bytes32 question_condition, uint _timeout) public onlyRole(MANAGER_ROLE) {
        Question storage question = questions[question_condition];
        require(_timeout > question.timeout, 'Wrong value');
        question.timeout = _timeout;
        emit TimeOutUpdated(question_condition, _timeout);
    }
    ///////////////////////////////////////////////////VIEW FUNCTIONS
    // candidate to deprecation (only used in tests)
    function getParentCollection(address dist) external view returns(bytes32) {
        return distributors[dist].collection;
    }
    function getTimeout(bytes32 condition) public view returns(uint) {
        return questions[condition].timeout;
    }

}
