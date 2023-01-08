// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IFactory {
    function getDistributorAddress(uint index) external view returns(address);
    function getCondition(uint index) external view returns(bytes32);
    function getParentCollection(uint index) external view returns(bytes32);
    function getTimeout(bytes32 condition) external view returns(uint);
    function changeTimeOut(bytes32 question_condition, uint _timeout) external;
    function createDistributor(
        bytes32 _parentCollection,
        address _collateralToken, 
        uint[] calldata _indexSets,
        uint template_index, 
        uint _question_index 
    ) external returns (address);
    function hasRole(bytes32 role, address account) external view returns(bool);
    function fee() external view returns(uint);
}
