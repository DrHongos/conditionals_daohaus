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
        bytes32 _conditionId,
        bytes32 parentCollection,
        IERC20 _collateralToken,
        uint[] calldata _indexSets,
        uint _amountToSplit,
        uint _timeOut
    ) external;

    event UserSetProbability(address who, uint[] userDistribution);
    event StatusChanged(Stages status);
    event UserRedemption(address who, uint[] redemption);
    event PredictionFunded(address who, uint amount);
    event TimeOutUpdated(uint timeOut);
    
    function setProbabilityDistribution(uint[] calldata distribution) external;
    function addFunds(uint amount) external;
    function close() external;
    function open() external;
    function redemptionTime() external;
    function changeTimeOut(uint _timeOut) external;
    function redeem() external;

}