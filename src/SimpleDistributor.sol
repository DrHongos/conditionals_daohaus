// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/ICT.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";


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
    
    uint[] indexSets;
    IERC20 collateralToken;
    uint amountToSplit;
    mapping(uint => uint) public positionsSum;
    mapping(address => bool) public userSet;
    mapping(address => uint[]) public probabilityDistribution;
    function initialize(
        bytes32 _conditionId,
        bytes32 parentCollection,
        IERC20 _collateralToken,
        uint[] calldata _indexSets,
        uint _amountToSplit
    ) initializer public {
        amountToSplit = _amountToSplit;
        collateralToken = _collateralToken;
        collateralToken.approve(CT_gnosis, amountToSplit);
        indexSets = _indexSets;
        collection = parentCollection;
        conditionId = _conditionId;
        ICT(CT_gnosis).splitPosition(
            collateralToken,
            parentCollection,
            conditionId,
            indexSets,
            amountToSplit
        );
        status = Stages.Open;
    }

    event UserSetProbability(address who, uint[] userDistribution);
    event StatusChanged(Stages status);
    event UserRedemption(address who, uint[] redemption);

    function setProbabilityDistribution(uint[] calldata distribution) public {
        address sender = msg.sender;
        require(status == Stages.Open, 'This contract is blocked');
        require(distribution.length == indexSets.length, 'Wrong distribution provided');        
        require(!userSet[sender], 'Call update function');
        uint sum;
        for (uint i = 0; i < indexSets.length; i++) {
            sum += distribution[i];
        }
        uint[] memory userPosition = new uint[](indexSets.length);        
        for (uint i = 0; i < indexSets.length; i++) {
            uint value = distribution[i] * decimals / sum;
            userPosition[i] = value;
            positionsSum[i] += value; // cannot update while this
        }
        probabilityDistribution[sender] = userPosition;
        userSet[sender] = true;
        emit UserSetProbability(sender, userPosition);
    }
    function update() public {
        // can erase position and reset.. or do the math
    }

    function close() public onlyOwner {
        status = Stages.Closed;
        emit StatusChanged(status);
    }
    function redemptionTime() public onlyOwner {
        // require condition is set (payoutDenominator)
        status = Stages.Redemption;
        emit StatusChanged(status);
    }    
    function redeem() public {        
        address payable sender = payable(msg.sender);
        require(status == Stages.Redemption, 'Redemption is still in the future');
        require(userSet[sender], 'User not registered or already redeemed');
        // return only the winner tokens?
        uint[] storage userPosition = probabilityDistribution[sender];
        uint[] memory returnedTokens = new uint[](indexSets.length);
        uint[] memory positionIds = new uint[](indexSets.length);
        userSet[sender] = false;
        bytes32 rootCollateral = 0x0000000000000000000000000000000000000000000000000000000000000000;
        for (uint i=0; i < indexSets.length; i++) {
            bytes32 collectionId = ICT(CT_gnosis).getCollectionId(
                rootCollateral,
                conditionId,
                indexSets[i]
            );
            uint positionId = ICT(CT_gnosis).getPositionId(
                address(collateralToken),
                collectionId
            );
            positionIds[i] = positionId;
            uint tokenBalance = ICT(CT_gnosis).balanceOf(address(this), positionId);
            returnedTokens[i] = amountToSplit * userPosition[i] / (positionsSum[i]); // * decimals            
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

