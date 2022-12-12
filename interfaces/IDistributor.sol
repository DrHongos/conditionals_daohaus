// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

//import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IDistributor {
    event UserSetProbability(address who, uint[] userDistribution);
    event UserRedemption(address who, uint[] redemption);
    event PredictionFunded(address who, uint amount);
    event TimeOutUpdated(uint timeOut);
    
    function initialize(
        bytes32 condition,
        bytes32 parentCollection,
        address collateral,
        uint timeout,
        uint[] calldata indexSets
    ) external;
    function checkQuestion() external;
    function setProbabilityDistribution(
        uint amount, 
        uint[] calldata distribution, 
        string calldata justification
    ) external;
    function addFunds(uint amount) external;
    function changeTimeOut(uint _timeOut) external;
    function redeem() external;

    function question_denominator() external view returns (uint);
    function question_numerator(uint) external view returns (uint); 
    function positionIds(uint) external view returns (uint);
    function indexSets(uint) external view returns (uint);

    function conditionId() external view returns (bytes32);
    function parentCollection() external view returns (bytes32);
    function totalBalance() external view returns (uint);
    function probabilityDistribution(address, uint) external view returns (uint);
    function timeout() external view returns (uint);
    function fee() external view returns (uint);
    function getUserRedemption(address who) external view returns (uint[] memory);
    function getProbabilityDistribution() external view returns (uint[] memory);
    function getUserPosition(address who) external view returns (uint[] memory);
//    function price() external view returns (uint);
}