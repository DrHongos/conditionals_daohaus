// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface ISimpleDistributor {
    enum Stages {
        Open,       //Accepts Positions 
        Closed,     //Rejects Positions         
        Redemption  //Redeems Positions
    }

    function initialize(
//        address creator,        
        bytes32 condition,
        bytes32 parentCollection,
        address collateral,
        uint[] calldata indexSets
//        address ct_address,        
//        uint question_index,
//        uint distributor_index        
    ) external;
    function configure(
        uint amountToSplit, 
        uint timeOut,
        uint price,
        uint fee
    ) external;
    event UserSetProbability(address who, uint[] userDistribution);
    event StatusChanged(Stages status);
    event UserRedemption(address who, uint[] redemption);
    event PredictionFunded(address who, uint amount);
    event TimeOutUpdated(uint timeOut);
    
    function checkQuestion() external;
    function question_denominator() external view returns (uint);

    function question_numerator(uint) external view returns (uint); 
    function positionIds(uint) external view returns (uint);
    function indexSets(uint) external view returns (uint);

    function conditionId() external view returns (bytes32);
    function parentCollection() external view returns (bytes32);
    function totalCollateral() external view returns (uint);
    function probabilityDistribution(address, uint) external view returns (uint);
    function status() external view returns (uint);
    function timeout() external view returns (uint);
    function price() external view returns (uint);
    function fee() external view returns (uint);
    function setProbabilityDistribution(uint amount, uint[] calldata distribution, string calldata justification) external;
    function addFunds(uint amount) external;
    function changeTimeOut(uint _timeOut) external;
    function redeem() external;
    function getUserRedemption(address who) external view returns (uint[] memory);
    function getProbabilityDistribution() external view returns (uint[] memory);
    function getUserPosition(address who) external view returns (uint[] memory);
}