// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ICT.sol";
import "../interfaces/IDistributor.sol"; // careful here.. initialization should be shared amongst all templates

//  TODO
// conditional distributors could be conditioned by question timelock (only if ends later than parent)
// fee mechanism (maybe in collateral?)

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
        bytes32 condition;   // pointer for the CT contracts
        bytes32 questionId;  // data related hash
        address creator;     // manager of this object
        address oracle;      // address that resolves the condition
        uint outcomes;       // number of outcomes
        uint timeout;        // time constraint
        bool launched;       // question launched (approved by CREATOR)
    }
    mapping(bytes32 => Question) public questions;    
    mapping(address => bool) public blocked;    
    mapping(uint => address) public templates;
    uint public questionsCount;
    uint public distributorsCount;

    event NewQuestionPrepared(
        address oracle, 
        address creator, 
        bytes32 condition, 
        bytes32 questionId, 
        uint outcomes, 
        uint timeout
    );
    event AddressBlocked(address who, bool blocking);
    event NewQuestionCreated(bytes32 condition, uint index);
    event QuestionRemoved(bytes32 condition, address who);
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

    ///@dev stores a new Question object
    function prepareQuestion(
        address _oracle,         // solver of the condition
        bytes32 _questionId,     // referrer to the condition (used to store IPFS cid of question data)
        uint _responses,         // number of possible outcomes
        uint _timeout
    ) public returns (bytes32 conditionId) {
        address _creator = msg.sender;
        require(!blocked[_creator], "User is blocked");
        require(!blocked[_oracle], "Oracle is blocked");
        conditionId = ICT(CT_CONTRACT).getConditionId(address(_oracle), _questionId, _responses);
        Question memory newQuestion = Question({
            condition: conditionId,
            questionId: _questionId,
            creator: _creator,
            oracle: _oracle, 
            outcomes: _responses,
            timeout: _timeout,
            launched: false
        });
        questions[conditionId] = newQuestion;
        emit NewQuestionPrepared(_oracle, _creator, conditionId, _questionId, _responses, _timeout);
    }

    ///@dev launches a new Question object
    function createQuestion(bytes32 condition) public {
        Question storage question = questions[condition];
        require(msg.sender == question.oracle, "Not the oracle");
        require(!blocked[msg.sender], "Oracle is blocked");
        require(question.launched == false, "Question launched");
        ICT(CT_CONTRACT).prepareCondition(question.oracle, question.questionId, question.outcomes);
        question.launched = true;
        questionsCount++;
        emit NewQuestionCreated(condition, questionsCount);
    }

    function blockAdddress(address gilipollas, bool blocking) public onlyRole(CREATOR_ROLE) {
        blocked[gilipollas] = blocking;
        emit AddressBlocked(gilipollas, blocking);
    }
    function removeQuestion(bytes32 condition) public onlyRole(CREATOR_ROLE) {
        Question storage question = questions[condition];
        question.launched = false;
        question.condition = "";
        question.questionId = "";
        question.oracle = address(0);
        emit QuestionRemoved(condition, msg.sender);
    }

    function DistributorChecks() internal returns(bool) {

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
        {
            require(ICT(CT_CONTRACT).payoutDenominator(_question_condition) == 0, "Question closed");
            uint outcomeSlotCount = ICT(CT_CONTRACT).getOutcomeSlotCount(_question_condition);
            uint fullIndexSet = (1 << outcomeSlotCount) - 1;
            uint result = 0;
            for (uint256 i = 0; i < _indexSets.length; i++) {
                result += _indexSets[i];
            }
            require(result == fullIndexSet, "Invalid indexSets");

            // check question is launched?

            // TODO: can check the timeout of both questions and allow/block its creation

        }
        
        address templateUsed = templates[template_index];
        require(templateUsed != address(0), "Template empty");

        bytes32 parentCollection;
        if (conditionalCondition != bytes32(0)) {
            parentCollection= ICT(CT_CONTRACT).getCollectionId(conditionalParentCollection, conditionalCondition, conditionalIndex);
        } else {
            parentCollection = bytes32(0);  // ROOT
        }

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
    function changeTimeOut(bytes32 condition, uint _timeout) public onlyRole(MANAGER_ROLE) {
        Question storage question = questions[condition];
        require(_timeout > question.timeout, 'Wrong value');
        question.timeout = _timeout;
        emit TimeOutUpdated(condition, _timeout);
    }
    ///////////////////////////////////////////////////VIEW FUNCTIONS
    function getTimeout(bytes32 condition) public view returns(uint) {
        return questions[condition].timeout;
    }

}
