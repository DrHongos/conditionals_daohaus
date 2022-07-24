// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/ICT.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

// TODO:
// add timeOut? maybe conditional?

contract SimpleDistributor is Ownable, Initializable, ERC1155Holder {

    enum Stages {
        Open,       //Accepts Positions 
        Closed,     //Rejects Positions         
        Redemption  //Redeems Positions
    }
    Stages status;
    constructor() {}
    // set it on initialization
    address CT_gnosis = 0xCeAfDD6bc0bEF976fdCd1112955828E00543c0Ce; 
    uint decimals = 100;
    bytes32 collection;
    bytes32 conditionId;
    uint timeOut;
    
    uint[] indexSets;
    IERC20 collateralToken;
    uint public totalCollateral;
    mapping(uint => uint) public positionsSum;
    mapping(address => bool) public userSet;
    mapping(address => uint[]) public probabilityDistribution;

    function initialize(
        bytes32 _conditionId,
        bytes32 parentCollection,
        IERC20 _collateralToken,
        uint[] calldata _indexSets,
        uint _amountToSplit,
        uint _timeOut
    ) initializer public {
        totalCollateral = _amountToSplit;
        collateralToken = _collateralToken;
        collateralToken.approve(CT_gnosis, _amountToSplit);
        indexSets = _indexSets;
        collection = parentCollection; // bytes32(0) for collateral
        conditionId = _conditionId;
        timeOut = _timeOut;
        ICT(CT_gnosis).splitPosition(
            _collateralToken,
            parentCollection,
            _conditionId,
            _indexSets,
            _amountToSplit
        );
        status = Stages.Open;
    }

    event UserSetProbability(address who, uint[] userDistribution);
    event StatusChanged(Stages status);
    event UserRedemption(address who, uint[] redemption);
    event PredictionFunded(address who, uint amount);
    event TimeOutUpdated(uint timeOut);
    
    function setProbabilityDistribution(uint[] calldata distribution) public {
        address sender = msg.sender;
        require(status == Stages.Open, 'This contract is blocked');
        require(distribution.length == indexSets.length, 'Wrong distribution provided');        
        if (timeOut > 0) {
            require(block.timestamp < timeOut, 'Time is out');
        }
        //require(!userSet[sender], 'Call update function');
        uint sum;
        for (uint i = 0; i < indexSets.length; i++) {
            sum += distribution[i];
        }
        uint[] memory newPosition = new uint[](indexSets.length);                
        for (uint i = 0; i < indexSets.length; i++) {
            uint value = distribution[i] * decimals / sum;
            newPosition[i] = value;
            positionsSum[i] += value;            
            if (userSet[sender]) {
                positionsSum[i] -= probabilityDistribution[sender][i];
            }    
        }
        probabilityDistribution[sender] = newPosition;
        userSet[sender] = true;
        emit UserSetProbability(sender, newPosition);
    }

    function addFunds(uint amount) public {
        require(status != Stages.Redemption, 'Prediction terminated');
        collateralToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        totalCollateral += amount;
        collateralToken.approve(CT_gnosis, amount);
        ICT(CT_gnosis).splitPosition(
            collateralToken,
            collection,
            conditionId,
            indexSets,
            amount
        );
        emit PredictionFunded(msg.sender, amount);
    }

    function close() public onlyOwner {
        status = Stages.Closed;
        emit StatusChanged(status);
    }
    function open() public onlyOwner {
        require(status != Stages.Redemption);
        status = Stages.Open;
        emit StatusChanged(status);
    }    
    function redemptionTime() public onlyOwner {
        status = Stages.Redemption;
        emit StatusChanged(status);
    }    
    function changeTimeOut(uint _timeOut) public onlyOwner {
        require(status != Stages.Redemption, 'Redemption done');
        timeOut = _timeOut;
        emit TimeOutUpdated(_timeOut);
    }
    function redeem() public {        
        address payable sender = payable(msg.sender);
        require(status == Stages.Redemption, 'Redemption is still in the future');
        require(userSet[sender], 'User not registered or already redeemed');        
        uint[] storage userPosition = probabilityDistribution[sender];
        uint[] memory returnedTokens = new uint[](indexSets.length);
        uint[] memory positionIds = new uint[](indexSets.length);
        userSet[sender] = false;
        for (uint i=0; i < indexSets.length; i++) {
            bytes32 collectionId = ICT(CT_gnosis).getCollectionId(
                collection,
                conditionId,
                indexSets[i]
            );
            uint positionId = ICT(CT_gnosis).getPositionId(
                address(collateralToken),
                collectionId
            );
            positionIds[i] = positionId;
            uint tokenBalance = ICT(CT_gnosis).balanceOf(address(this), positionId);
            returnedTokens[i] = totalCollateral * userPosition[i] / (positionsSum[i]); // * decimals            
        }
        IERC1155(CT_gnosis).safeBatchTransferFrom(
            address(this),
            sender,
            positionIds,
            returnedTokens,
            '0x'
        );
        emit UserRedemption(sender, returnedTokens);
    }    

}

