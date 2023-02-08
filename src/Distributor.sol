// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

// TODO: fee logic

import "../interfaces/ICT.sol";
import "../interfaces/IFactory.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

contract Distributor is Initializable, ERC1155Holder, ReentrancyGuard {
    bytes32 public conditionId;         // refers to the question   // pasaria a ser conditions[last]
    
    //bytes32 public parentCollection;    // refers to the liquidity (root / conditional (collection))

    bytes32[] public conditions;
    uint[] public conditionsIndexes;
    // work on here.. keep list of conditions / collections & indexes
    // and any call transform collateral into conditionals
    // el problema al splittear es generar los indexSets para cada condition
    // quiza lo mejor es quitar el index y luego dejar valores base
    //uint public fee;                  // to implement



    uint price;
    // this refers to the direct upward question
    uint public question_denominator; // store it when question is answered & internal boolean for status = redeem
    uint[] public question_numerator; // result of the question, avoiding recurrent internal calls

    address public opinologos;        // questions factory
    address public factory;           // factory that creates this
    uint[] public indexSets;          // To select the positions
    uint[] public positionIds;        // store the position ids

    address public collateralToken;   // ERC20 backing the tokens in game
    ICT conditionalTokens;            // matrix of conditional tokens
    uint public totalBalance;         // keeper of the total balance
    mapping(uint => uint) public positionsSum;  // global sum of each position (weighted)
    struct UserPosition {
        bool payed;
        //uint positionSize;                // to handle price band
        uint[] probabilityDistribution;   // position discrimination
        string justifiedPositions;        // this one is expensive and not needed
    }
    mapping (address => UserPosition) public positions;
    mapping(address => bool) public redeemed;

        //bytes32 parentCollection,
    event DistributorInitialized(
        address collateralToken,
        bytes32 condition,              
        uint price
    );
    event UserSetProbability(address who, uint[] userDistribution, string justification);
    event UserRedemption(address who, uint[] redemption);
    event DistributorFunded(address who, uint amount);

    modifier openQuestion() {
        require(question_denominator == 0, "Question answered");
        _;
    }

    constructor() {}

    function initialize(
        bytes32[] calldata _conditions,
        uint[] calldata _conditionsIndexes,
        address _opinologos,
        address _collateral,                    
        uint _price,
        uint[] calldata _indexSets
    ) initializer public {
        factory = msg.sender;
        opinologos = _opinologos;
        conditions = _conditions;
        conditionId = _conditions[_conditions.length - 1];  // last condition
        conditionsIndexes = _conditionsIndexes;
        indexSets = _indexSets;
        collateralToken = _collateral;
        price = _price;
        address CT_gnosis = 0xCeAfDD6bc0bEF976fdCd1112955828E00543c0Ce; // gnosis chain CT contract
        conditionalTokens = ICT(CT_gnosis);
        //fee = IFactory(factory).fee();
        
        bytes32 parentCollection = IFactory(factory).distributorParent(address(this));
        for (uint i=0; i < _indexSets.length; i++) {
            positionIds.push(
                conditionalTokens.getPositionId(_collateral,
                    conditionalTokens.getCollectionId(parentCollection, conditionId, _indexSets[i]))
            );
        }

        emit DistributorInitialized(
            _collateral,
            conditionId,
//            parentCollection,
            _price
        );
    }

    function addFunds(uint amount) public openQuestion {
        totalBalance += amount;
        address sender = msg.sender;
        require(IERC20(collateralToken).transferFrom(msg.sender, address(this), amount), "cost transfer failed");
        require(IERC20(collateralToken).approve(address(conditionalTokens), amount), "approval for splits failed");
        // loop to get to the final positions,
        bytes32 collection = bytes32(0);
        for (uint i = 0; i < conditions.length; i++) {
            uint outcomes = conditionalTokens.getOutcomeSlotCount(conditions[i]);            
            uint[] memory indexSetsFetched = conditions[i] == conditionId ? indexSets : getIndexes(outcomes, conditionsIndexes[i]);//generateBasicPartition(outcomes);

            conditionalTokens.splitPosition(IERC20(collateralToken), collection, conditions[i], indexSetsFetched, amount); 
            if (i != conditions.length - 1) {
                uint[] memory returnPositions = new uint[](indexSetsFetched.length);
                uint[] memory returnAmounts = new uint[](indexSetsFetched.length);
                for (uint j = 0; j < indexSetsFetched.length; j++) {
                    uint index = 1 << j;
                    if (index != conditionsIndexes[i]) {
                        uint positionId = conditionalTokens.getPositionId(collateralToken,
                            conditionalTokens.getCollectionId(collection, conditions[i], index));
                        returnPositions[j] = positionId;
                        returnAmounts[j] = amount;
                    }

                }
                conditionalTokens.safeBatchTransferFrom(address(this), sender, returnPositions, returnAmounts, "");
            }
            collection = conditionalTokens.getCollectionId(collection, conditions[i], conditionsIndexes[i]);            

        }
        emit DistributorFunded(sender, amount);
    }

    function binaryIndexes(uint256 input) internal view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](256);
        uint256 count = 0;
        for (uint256 i = 0; i <= input; i++) {
            if ((input & (1 << i)) != 0) {
                result[count] = i;
                count++;
            }
        }
        uint256[] memory retornar = new uint[](count);
        for (uint j = 0; j < count; j++) {
            retornar[j] = 1 << result[j];   // converted to value
        }
        return retornar;
    }

    function getIndexes(uint outcomes, uint index) internal view returns (uint[] memory) {
        uint fullIndexSet = (1 << outcomes) - 1;
        uint rest = fullIndexSet - index;
        uint[] memory indexes = binaryIndexes(rest);
        uint retLength = indexes.length + 1;
        uint[] memory ret = new uint[](retLength);
        uint i;
        for (i = 0; i <= indexes.length; i++) {
            if(i == indexes.length || indexes[i] > index) {
                ret[i] = index;
                break;
            } 
            ret[i] = indexes[i];
        }            
        for(i = i + 1; i < retLength; i++) {
            ret[i] = indexes[i - 1];
        }
        return ret;
    }

/*     function generateBasicPartition(uint outcomeSlotCount)
        private
        pure
        returns (uint[] memory partition)
    {
        partition = new uint[](outcomeSlotCount);
        for(uint i = 0; i < outcomeSlotCount; i++) {
            partition[i] = 1 << i;
        }
    } */

    function setProbabilityDistribution(
        uint[] calldata distribution,
        string calldata justification
    ) public openQuestion {
        if (guardQuestionStatus()) return;               // finish early
        uint len = indexSets.length;
        require(distribution.length == len, 'Wrong distribution provided');
        uint timeout = IFactory(opinologos).getTimeout(conditionId); // change this
        if (timeout > 0) {
            require(block.timestamp < timeout, 'Time is out');
        }
        address sender = msg.sender;
        UserPosition storage user = positions[sender];
        if (price > 0 && !user.payed) {
            addFunds(price);
            user.payed = true;
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
            uint value = distribution[i] * 1000 / sum;
            newPosition[i] = value;
            positionsSum[i] += value;// * weight;
            if (user.probabilityDistribution.length > 0) {
                positionsSum[i] -= user.probabilityDistribution[i];
            }
        }
        //---
        user.probabilityDistribution = newPosition;
        emit UserSetProbability(sender, newPosition, justification);
    }

    function redeem() public nonReentrant {
        address payable sender = payable(msg.sender);
        require(question_denominator != 0, 'Redemption is still in the future');
        require(!redeemed[msg.sender], 'Done');
        uint[] memory returnedTokens = getUserRedemption(sender);
        redeemed[msg.sender] = true;
        IERC1155(address(conditionalTokens)).safeBatchTransferFrom(
            address(this),
            sender,
            positionIds,
            returnedTokens,
            '0x'
        );
        emit UserRedemption(sender, returnedTokens);
    }

    // alternative to call setProbabilityDistribution to detect a question is answered.. deprecate?
    function checkQuestion() public {
        guardQuestionStatus();
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
/////////////////////////////////////////////////// VIEW FUNCTIONS
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
            uint pos = user.probabilityDistribution[i];
            if (pos != 0) {
                returnedTokens[i] = (totalBalance * pos) / positionsSum[i];
            } else {
                returnedTokens[i] = 0;
            }
        }
        return returnedTokens;
    }
    function getUserPosition(address who) public view returns(uint[] memory) {
        return positions[who].probabilityDistribution;
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

