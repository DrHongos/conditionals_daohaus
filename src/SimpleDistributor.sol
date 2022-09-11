// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

// TODO ;
// WRITE FUNCTIONS FOR
// FEE
// PRICE
// 

import "../interfaces/ICT.sol";
import "../interfaces/IQuestionFactory.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";


contract SimpleDistributor is Initializable, ERC1155Holder, AccessControl {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 rootCollateral = 0x0000000000000000000000000000000000000000000000000000000000000000; 
    enum Stages {
        Preparing,  //Awaiting configuration
        Open,       //Accepts Positions 
        Closed,     //Rejects Positions         
        Redemption  //Redeems Positions
    }
    Stages public status;
    uint public timeout;
    uint public price;
    uint public fee;
    
    uint public question_index;
    uint public distributor_index;

    address public factory;    
    uint[] public indexSets;
    IERC20 public collateralToken;
    ICT conditionalTokens;
    uint public totalCollateral;
    mapping(uint => uint) public positionsSum;
    mapping(address => bool) public userSet;
    mapping(address => uint[]) public probabilityDistribution;
    mapping(address => string) public justifiedPositions;

    event SimpleDistributorInitialized(
        address collateralToken,
        address creator,
        uint[] indexSets,
        uint question_index,
        uint distributor_index
    );
    event DistributorStarted(uint initial_amount, uint timeout, uint price, uint fee);
    event UserSetProbability(address who, uint[] userDistribution, string justification);
    event StatusChanged(Stages status);
    event UserRedemption(address who, uint[] redemption);
    event PredictionFunded(address who, uint amount);
    event TimeOutUpdated(uint timeout);
    
    constructor() {}


    function initialize(        
        address creator,
        address _collateral,
        address ct_address,        
        uint[] calldata _indexSets,        
        uint _question_index,
        uint _distributor_index
    ) initializer public {
        factory = msg.sender;
        _grantRole(MANAGER_ROLE, factory);
        _grantRole(DEFAULT_ADMIN_ROLE, factory);
        _grantRole(MANAGER_ROLE, creator);
        question_index = _question_index;
        distributor_index = _distributor_index;        
        indexSets = _indexSets;
        collateralToken = IERC20(_collateral);
        conditionalTokens = ICT(ct_address);
        status = Stages.Preparing;
        emit SimpleDistributorInitialized(
            _collateral,
            creator,
            _indexSets,
            _question_index,
            _distributor_index
        );
    }

    function configure(
        uint _amountToSplit, 
        uint _timeout,
        uint _price,
        uint _fee
    ) public onlyRole(MANAGER_ROLE) {
        // checks (timenow > now)
        // amountToSplit > 0
        // fee < 5%
        price = _price;
        fee = _fee;
        timeout = _timeout;
        bytes32 conditionId = IQuestionFactory(factory).getCondition(question_index); // it does not change..
        addFunds(conditionId, _amountToSplit);
        status = Stages.Open;
        emit DistributorStarted(_amountToSplit, _timeout, _price, _fee);
    }

    function addFunds(bytes32 conditionId, uint amount) public {
        require(status != Stages.Redemption, 'Prediction terminated');
        collateralToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        totalCollateral += amount;
        collateralToken.approve(address(conditionalTokens), amount);
        bytes32 collection = IQuestionFactory(factory).getParentCollection(distributor_index);
        conditionalTokens.splitPosition(
            collateralToken,
            collection, 
            conditionId,
            indexSets,
            amount
        );
        emit PredictionFunded(msg.sender, amount);
    }

    function setProbabilityDistribution(
        uint[] calldata distribution,
        string calldata justification
    ) public {
        address sender = msg.sender;
        uint len = indexSets.length;
        require(status == Stages.Open, 'Contract not open');
        require(distribution.length == len, 'Wrong distribution provided');        
        if (timeout > 0) {
            require(block.timestamp < timeout, 'Time is out');
        }
        justifiedPositions[sender] = justification;
        uint sum;
        for (uint i = 0; i < len; i++) {
            sum += distribution[i];
        }
        require(sum > 0, "At least one value");
        uint[] memory newPosition = new uint[](len);                
        if (!userSet[sender] && price > 0) {
            bytes32 conditionId = IQuestionFactory(factory).getCondition(question_index);
            addFunds(conditionId, price); // test
        }
        for (uint i = 0; i < len; i++) {
            uint value = distribution[i] * 100 / sum;
            newPosition[i] = value;
            positionsSum[i] += value;            
    // the only reference to if its the first participation.. cannot add price payment in here
            if (userSet[sender]) {
                positionsSum[i] -= probabilityDistribution[sender][i];
            }    
        }
        probabilityDistribution[sender] = newPosition;
        userSet[sender] = true;
        emit UserSetProbability(sender, newPosition, justification);
    }

    function close() public onlyRole(MANAGER_ROLE) {
        status = Stages.Closed;
        emit StatusChanged(status);
    }
    function open() public onlyRole(MANAGER_ROLE) {
        require(status != Stages.Redemption);
        status = Stages.Open;
        emit StatusChanged(status);
    }    
    function redemptionTime() public onlyRole(MANAGER_ROLE) {
        status = Stages.Redemption;
        emit StatusChanged(status);
    }    
    function changeTimeOut(uint _timeout) public onlyRole(MANAGER_ROLE) {
        require(status != Stages.Redemption, 'Redemption done');
        require(_timeout > timeout, 'Wrong value');
        timeout = _timeout;
        emit TimeOutUpdated(_timeout);
    }
    function redeem() public {        
        address payable sender = payable(msg.sender); // payable for ERC1155?
        require(status == Stages.Redemption, 'Redemption is still in the future');
        require(userSet[sender], 'User not registered or already redeemed');        
        userSet[sender] = false; // maybe a bool "redeemed"
        (uint[] memory positionIds, uint[] memory returnedTokens) = getUserRedemption(sender);
        IERC1155(address(conditionalTokens)).safeBatchTransferFrom(
            address(this),
            sender,
            positionIds,
            returnedTokens,
            '0x'
        );
        // what!? i need to diminish the total results!
        emit UserRedemption(sender, returnedTokens);
    }

    function getCollateral() public view returns (address) {
        return address(collateralToken);
    }

    function getProbabilityDistribution() public view returns (uint[] memory) {
        uint size = indexSets.length;
        uint[] memory current = new uint[](size);
        for (uint i = 0; i < size; i++) {
            current[i] = positionsSum[i];
        }
        return current;
    }

    function getUserRedemption(address who) public view returns(uint[] memory, uint[] memory) {
        bytes32 collection = IQuestionFactory(factory).getParentCollection(distributor_index);
        bytes32 conditionId = IQuestionFactory(factory).getCondition(question_index);
        uint[] memory returnedTokens = new uint[](indexSets.length);
        uint[] memory positionIds = new uint[](indexSets.length);
        for (uint i=0; i < indexSets.length; i++) {
            bytes32 collectionId = conditionalTokens.getCollectionId(
                collection,
                conditionId,
                indexSets[i]
            );
            uint positionId = conditionalTokens.getPositionId(
                address(collateralToken),
                collectionId
            );
            positionIds[i] = positionId;
            returnedTokens[i] = totalCollateral * probabilityDistribution[who][i] / (positionsSum[i]);
        }
        return (positionIds, returnedTokens);
    }

    ///@dev support interface should concatenate all supported interfaces
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC1155Receiver)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


}

