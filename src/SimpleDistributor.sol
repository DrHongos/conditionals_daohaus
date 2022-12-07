// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

// TODO:
// test user as struct
// change price to a band of prices         <<
    // handle relation between amount and returnedTokens
// Fee (config address + percenteage)       <
// try to unify initialization + config
// separate library content
// OTHERS
// user _should_ redeem collateral directly 
// 

import "../interfaces/ICT.sol";
import "../interfaces/IQuestionFactory.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

contract SimpleDistributor is Initializable, ERC1155Holder, ReentrancyGuard {
    bytes32 public conditionId;
    bytes32 public parentCollection;

    uint public timeout;              // can be uint64
    uint public price;                // change it to min/max
    uint public fee;                  // to implement

    uint public question_denominator; // store it when question is answered & internal boolean for status = redeem
    uint[] public question_numerator; // result of the question, avoiding recurrent internal calls

    address public factory;           // factory that creates this
    uint[] public indexSets;          // To select the positions
    uint[] public positionIds;        // store the position ids

    IERC20 public collateralToken;    // ERC20 backing the tokens in game
    ICT conditionalTokens;            // matrix of conditional tokens
    uint public totalCollateral;      // keeper of the total balance

    // TODO: transform to weighted positions in order to open price to be variable
    mapping(uint => uint) public positionsSum;  // global sum of each position

    // users data
    //mapping(address => bool) public userSet;    // more like user is active 
    //mapping(address => uint[]) public probabilityDistribution;  // check its not hackable, limit its top number 
    //mapping(address => string) public justifiedPositions;       // optional string for user

    // alternative 
    struct UserPosition {
        uint positionSize;                // to handle price band
        uint[] probabilityDistribution;   // position discrimination
        string justifiedPositions;        // this one is expensive and not needed
    }
    mapping (address => UserPosition) public positions;

    event SimpleDistributorInitialized(
        address collateralToken,
        uint[] indexSets,
        bytes32 condition,
        bytes32 parentCollection
    );
    event DistributorStarted(uint initial_amount, uint timeout, uint price, uint fee);
    event UserSetProbability(address who, uint[] userDistribution, uint amount, string justification);
    event UserRedemption(address who, uint[] redemption);
    event PredictionFunded(address who, uint amount);
    event TimeOutUpdated(uint timeout);
    
    constructor() {}
/* 
Can initialization and configuration be just one?
*/
    function initialize(
        bytes32 _condition,
        bytes32 _parentCollection,
        address _collateral,
        uint[] calldata _indexSets
    ) initializer public {
        factory = msg.sender;
        conditionId = _condition;
        parentCollection = _parentCollection;
        indexSets = _indexSets;
        collateralToken = IERC20(_collateral);
        address CT_gnosis = 0xCeAfDD6bc0bEF976fdCd1112955828E00543c0Ce;
        conditionalTokens = ICT(CT_gnosis);
        for (uint i=0; i < _indexSets.length; i++) {
            bytes32 collectionId = conditionalTokens.getCollectionId(
                _parentCollection,
                _condition,
                _indexSets[i]
            );
            uint positionId = conditionalTokens.getPositionId(
                _collateral,
                collectionId
            );
            positionIds.push(positionId);
        }
        emit SimpleDistributorInitialized(
            _collateral,
            _indexSets,
            _condition,
            _parentCollection
        );
    }
    function configure(
        uint _amountToSplit,  // deprecate this 
        uint _timeout,
        uint _price,
        uint _fee
    ) public { 
        // checks (timeout > now)
        // amountToSplit > 0
        // fee < 5% // baseFee + creatorsFee
        require(totalCollateral == 0, "Already config");
        price = _price;
        fee = _fee;
        timeout = _timeout;
        addFunds(_amountToSplit);
        emit DistributorStarted(_amountToSplit, _timeout, _price, _fee);
    }

    function addFunds(uint amount) public {
        collateralToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        totalCollateral += amount;
        collateralToken.approve(address(conditionalTokens), amount);
        conditionalTokens.splitPosition(
            collateralToken,
            parentCollection, 
            conditionId,
            indexSets,
            amount
        );
        emit PredictionFunded(msg.sender, amount);
    }

// alternative to call setProbabilityDistribution to detect a question is answered.. deprecate?
    function checkQuestion() public {
        guardQuestionStatus();
    }

    // users set its position in the distributor, pay the price (if required) and update if existent
    function setProbabilityDistribution(
        uint amount,
        uint[] calldata distribution,
        string calldata justification
    ) public {
        require(totalCollateral != 0, 'Contract not open'); // hack to check configuration is done
        require(question_denominator == 0, "Question answered");
        if (guardQuestionStatus()) return; // finish early
        uint len = indexSets.length;        
        require(distribution.length == len, 'Wrong distribution provided');
        if (timeout > 0) {
            require(block.timestamp < timeout, 'Time is out');
        }
        address sender = msg.sender;
        UserPosition storage user = positions[sender];
        uint weight = user.positionSize + amount;           // TODO: handle amount = 0 (for forms templates)
        require(weight >= price, "Price is bigger"); // checks the price payment done
        if (amount > 0) {
            addFunds(amount);
        }
        user.justifiedPositions = justification;
        //---
        uint sum;
        for (uint i = 0; i < len; i++) {
            sum += distribution[i];
        }
        require(sum > 0, "At least one value");
        uint[] memory newPosition = new uint[](len);                
        for (uint i = 0; i < len; i++) {
            uint value = distribution[i] * 100 / sum;
            newPosition[i] = value;
            positionsSum[i] += value * weight;
            if (user.probabilityDistribution.length > 0) {
                positionsSum[i] -= user.probabilityDistribution[i] * user.positionSize;
            }
        }
        //---
        user.positionSize = weight;
        user.probabilityDistribution = newPosition;
        emit UserSetProbability(sender, newPosition, amount, justification);
    }

    // maybe deprecate this? its failing as it is.. now we have no more roles!
    function changeTimeOut(uint _timeout) public { // onlyRole(MANAGER_ROLE)
        //require(msg.sender == factory, "Nope");
        require(question_denominator == 0, 'Question is answered');
        require(_timeout > timeout, 'Wrong value');
        timeout = _timeout;
        emit TimeOutUpdated(_timeout);
    }
/////////////////////////////////////////////////////

    // TODO: 
    // redeem should call CT and return collateral directly, 
    // 2 steps to do so its bad UX, but for the moment..
    function redeem() public nonReentrant {
        address payable sender = payable(msg.sender); // payable for ERC1155?
        require(question_denominator != 0, 'Redemption is still in the future');
        //
        UserPosition storage user = positions[sender]; 
        //require(userSet[sender], 'User not registered or already redeemed');        
        //userSet[sender] = false; // maybe a bool "redeemed"
        uint[] memory returnedTokens = getUserRedemption(sender);
        IERC1155(address(conditionalTokens)).safeBatchTransferFrom(
            address(this),
            sender,
            positionIds,
            returnedTokens,
            '0x'
    );

/* 
        Note, redeemPositions checks the caller balance and makes the logic to transform to collateral.
        In case y should control internally the proportional balance and get rid of ERC1155 manipulation (burned when redeemed)
        study and test better..
 */
        // redeemPositions(IERC20 collateralToken, bytes32 parentCollectionId, bytes32 conditionId, uint[] calldata indexSets)
        // call it in behalf of msg.sender or what?
//        conditionalTokens.redeemPositions(collateralToken, rootCollateral, conditionId, indexSets);
        // what!? i need to diminish the total results!  ((??? wtf is this comment))
        emit UserRedemption(sender, returnedTokens);
    }

    function getCollateral() public view returns (address) {
        return address(collateralToken);
    }
    // gives a live general position (and number of outcomes)
    function getProbabilityDistribution() public view returns (uint[] memory) {
        uint size = indexSets.length;
        uint[] memory current = new uint[](size);
        for (uint i = 0; i < size; i++) {
            current[i] = positionsSum[i];
        }
        return current;
    }
    function getUserRedemption(address who) public view returns(uint[] memory) {
        uint[] memory returnedTokens = new uint[](indexSets.length);
        UserPosition memory user = positions[who];
        for (uint i=0; i < indexSets.length; i++) {
            uint weighted = user.probabilityDistribution[i] * user.positionSize; // handle positionSize = 0
            if (weighted != 0) {
                returnedTokens[i] = (totalCollateral * weighted) / positionsSum[i];
            } else {
                returnedTokens[i] = 0;
            }
        }
        return returnedTokens;
    }
    function getUserPosition(address who) public view returns(uint[] memory) {
        return positions[who].probabilityDistribution;
    }

    function guardQuestionStatus() internal returns(bool) {
        uint root_denominator = conditionalTokens.payoutDenominator(conditionId);
        if(root_denominator != 0) {
            question_denominator = root_denominator;
            for (uint i = 0; i < indexSets.length; i++) {// can be unsafe
                question_numerator.push(conditionalTokens.payoutNumerators(conditionId, i));
            }
            return true;
        } else return false;
    }
    ///@dev support interface should concatenate all supported interfaces
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Receiver)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

