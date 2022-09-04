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
        address creator,        
        address collateral,
        address ct_address,        
        uint[] calldata indexSets,        
        uint question_index,
        uint distributor_index        
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
    
    function status() external view returns (uint);
    function timeout() external view returns (uint);
    function price() external view returns (uint);
    function fee() external view returns (uint);
    function userSet(address) external view returns (bool);
    function probabilityDistribution(address) external view returns (uint[] calldata);
    function setProbabilityDistribution(uint[] calldata distribution) external;
    function addFunds(uint amount) external;
    function close() external;
    function open() external;
    function redemptionTime() external;
    function changeTimeOut(uint _timeOut) external;
    function redeem() external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function grantRole(bytes32 role, address account)  external;
    function revokeRole(bytes32 role, address account)  external;
    function getUserRedemption(address who) external view returns (uint[] memory, uint[] memory);
}