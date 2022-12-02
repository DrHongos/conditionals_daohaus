// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ICT.sol";
import "../interfaces/ISimpleDistributor.sol"; // careful here.. initialization should be shared amongst all templates (?)

//  TODO
//  que el creador pague a Opinologos el valor del precio del distribuidor
//  y luego recupere con su franja de 0/3 %
//  poner precio minimo actualizable
//  
contract QuestionsFactory is AccessControl {
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant CURATOR_ROLE = keccak256("CURATOR_ROLE");
    
    address CT_CONTRACT;

    struct Distributor {
        bytes32 collection;
        address contract_address;
        address template;
        uint question_index;
    }

    struct Question {
        bytes32 condition;        
        bytes32 questionId; // in doubt
        address creator;    //     "
        address oracle;     //     "
        uint outcomes;
    }

    mapping(uint => address) public templates;
    // also thinking about mapping(uint => bytes32) conditions & mapping(bytes32 => Question)
    mapping(uint => Question) public questions;
    uint public questionsCount;
    mapping(uint => Distributor) public distributors;
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
        uint distributorIndex,
        address templateUsed, 
        uint question_index
    );
    event DistributorTemplateChanged(address newTemplate, uint index);

    constructor(address _CT_CONTRACT) {
        CT_CONTRACT = _CT_CONTRACT;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    ///@dev creates a new condition and stores it
    function createQuestion(
        address _oracle,         // solver of the condition
        // TODO receive a string and create the bytes32 (so my event can have the cid directly?)
        bytes32 _questionId,     // referrer to the condition (used to store IPFS cid of question data)
        uint _responses       // number of possible outcomes
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
        uint usingIndex = questionsCount;
        questions[usingIndex] = newQuestion;
        questionsCount++;
        emit NewQuestionCreated(_oracle, _creator, conditionId, _questionId, _responses, usingIndex);
    }

//        onlyRole(CREATOR_ROLE)
    function createDistributor(
        bytes32 _parentCollection, // frontend managed
        address _collateralToken, // token of the distributor
        uint[] calldata _indexSets, // groups for outcomes
        uint template_index, // template index
        uint _question_index  // question index (maybe should be condition)
    )
        external
        returns (address newDistributorAddress)
    {
// NOTICE!! the test below is blocked for test issues.
// require(ICT(CT_CONTRACT).payoutDenominator(questions[_question_index].condition) != 0, "Question closed");
        address templateUsed = templates[template_index];
        require(templateUsed != address(0), "Template empty");

        newDistributorAddress = Clones.clone(templateUsed);
        uint newIndex = distributorsCount;
        Distributor memory newDistributor = Distributor({
            collection: _parentCollection,
            contract_address: newDistributorAddress,
            template: templateUsed,
            question_index: _question_index        
        });
        distributors[newIndex] = newDistributor;
        // TODO: this should be a general implementation of the initialize function
        /* 
            collateral,
            condition,
            parentCollection,
            indexes
            +
            configs (depends on the template..)
         */    
        ISimpleDistributor(newDistributorAddress).initialize(
//            msg.sender,
            questions[_question_index].condition,
            _parentCollection,
            _collateralToken,
            _indexSets
//            CT_CONTRACT,        // maybe not needed on every creation            
        );   

        distributorsCount += 1;
        emit DistributorCreated(
            newDistributorAddress, 
            newIndex, 
            templateUsed,             
            _question_index
        );
    }
/*     function revokeRoleInDistributor(address account, uint index) public onlyRole(CURATOR_ROLE) {
        ISimpleDistributor(distributors[index].contract_address).revokeRole(MANAGER_ROLE, account);
    }
    function grantRoleInDistributor(address account, uint index) public onlyRole(CURATOR_ROLE) {
        ISimpleDistributor(distributors[index].contract_address).revokeRole(MANAGER_ROLE, account);
    }
    function redemptionTimeInDistributor(uint index) public onlyRole(CURATOR_ROLE) {
        ISimpleDistributor(distributors[index].contract_address).redemptionTime();
    }  
    function closeInDistributor(uint index) public onlyRole(CURATOR_ROLE) {
        ISimpleDistributor(distributors[index].contract_address).close();        
    }   */
    function setTemplate(address _newTemplate, uint index)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        templates[index] = _newTemplate;
        emit DistributorTemplateChanged(_newTemplate, index);
    }
    ///////////////////////////////////////////////////VIEW FUNCTIONS
    function getDistributorAddress(uint index) external view returns (address) {
        return distributors[index].contract_address;
    }
    // i dont like this ones, but let's see
    function getCondition(uint index) external view returns(bytes32) {
        return questions[index].condition;
    }
    function getParentCollection(uint index) external view returns(bytes32) {
        return distributors[index].collection;
    }
}
