// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "../interfaces/ICT.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

contract SimpleDistributor is Initializable, ERC1155Holder {

    enum Stages {
        Open,       //Accepts Positions 
        Closed,     //Rejects Positions         
        Redemption  //Redeems Positions
    }
    Stages public status;
    address ctAddress;
    bytes32 public collection;
    bytes32 public conditionId;
    uint public timeOut;
    address public owner;
    
    uint[] public indexSets;
    IERC20 collateralToken;
    uint public totalCollateral;
    mapping(uint => uint) public positionsSum;
    mapping(address => bool) public userSet;
    mapping(address => uint[]) public probabilityDistribution;
    mapping(address => string) public justifiedPositions;

    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    event SimpleDistributorInitialized(
        bytes32 conditionId,
        bytes32 parentCollection,
        address collateralToken,
        address ctAddress,
        uint[] indexSets,
        uint amountToSplit,
        uint timeOut
    );
    event UserSetProbability(address who, uint[] userDistribution, string justification);
    event StatusChanged(Stages status);
    event UserRedemption(address who, uint[] redemption);
    event PredictionFunded(address who, uint amount);
    event TimeOutUpdated(uint timeOut);
    
    constructor() {}
    function initialize(        
        bytes32 _conditionId,
        bytes32 parentCollection,
        address _collateralToken,
        address _ctAddress,
        uint[] calldata _indexSets,
        uint _amountToSplit,
        uint _timeOut
    ) initializer public {
        owner = msg.sender;
        totalCollateral = _amountToSplit;
        collateralToken = IERC20(_collateralToken);
        collateralToken.approve(_ctAddress, _amountToSplit);
        indexSets = _indexSets;
        ctAddress = _ctAddress;
        collection = parentCollection; // bytes32(0) for collateral
        conditionId = _conditionId;
        timeOut = _timeOut;
        ICT(_ctAddress).splitPosition(
            collateralToken,
            parentCollection,
            _conditionId,
            _indexSets,
            _amountToSplit
        );
        status = Stages.Open;
        emit SimpleDistributorInitialized(
            _conditionId,
            parentCollection,
            _collateralToken,
            _ctAddress,
            _indexSets,
            _amountToSplit,
            _timeOut
        );
    }

    function setProbabilityDistribution(
        uint[] calldata distribution,
        string calldata justification
    ) public {
        address sender = msg.sender;
        uint len = indexSets.length;
        require(status == Stages.Open, 'This contract is blocked');
        require(distribution.length == len, 'Wrong distribution provided');        
        if (timeOut > 0) {
            require(block.timestamp < timeOut, 'Time is out');
        }
        justifiedPositions[sender] = justification;
        uint sum;
        for (uint i = 0; i < len; i++) {
            sum += distribution[i];
        }
        require(sum > 0, "At least one value");
        uint[] memory newPosition = new uint[](len);                
        for (uint i = 0; i < len; i++) {
            uint value = distribution[i] * 100 / sum;
            newPosition[i] = value;
            positionsSum[i] += value;            
            if (userSet[sender]) {
                positionsSum[i] -= probabilityDistribution[sender][i];
            }    
        }
        probabilityDistribution[sender] = newPosition;
        userSet[sender] = true;
        emit UserSetProbability(sender, newPosition, justification);
    }

    function addFunds(uint amount) public {
        require(status != Stages.Redemption, 'Prediction terminated');
        collateralToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        totalCollateral += amount;
        collateralToken.approve(ctAddress, amount);
        ICT(ctAddress).splitPosition(
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
        require(_timeOut > timeOut, 'Wrong value');
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
            bytes32 collectionId = ICT(ctAddress).getCollectionId(
                collection,
                conditionId,
                indexSets[i]
            );
            uint positionId = ICT(ctAddress).getPositionId(
                address(collateralToken),
                collectionId
            );
            positionIds[i] = positionId;
            //uint tokenBalance = ICT(ctAddress).balanceOf(address(this), positionId);
            returnedTokens[i] = totalCollateral * userPosition[i] / (positionsSum[i]); // * decimals            
        }
        IERC1155(ctAddress).safeBatchTransferFrom(
            address(this),
            sender,
            positionIds,
            returnedTokens,
            '0x'
        );
        emit UserRedemption(sender, returnedTokens);
    }

    function getProbabilityDistribution() public view returns (uint[] memory) {
        uint size = indexSets.length;
        uint[] memory current = new uint[](size);
        for (uint i = 0; i < size; i++) {
            current[i] = positionsSum[i];
        }
        return current;
    }

}

