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
    
    address CT_CONTRACT;
    uint public fee;

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
//    mapping(uint => address) public templates;
    uint public questionsCount;

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

//    event DistributorTemplateChanged(address newTemplate, uint index);
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

    function blockAdddress(address who, bool blocking) public onlyRole(CREATOR_ROLE) {
        blocked[who] = blocking;
        emit AddressBlocked(who, blocking);
    }

    function removeQuestion(bytes32 condition) public onlyRole(CREATOR_ROLE) {
        Question storage question = questions[condition];
        question.launched = false;
        question.condition = "";
        question.questionId = "";
        question.oracle = address(0);
        emit QuestionRemoved(condition, msg.sender);
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
    function getOutcomes(bytes32 condition) public view returns(uint) {
        return questions[condition].outcomes;
    }

}
