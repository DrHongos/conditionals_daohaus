// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IQuestionFactory {
    function getDistributorAddress(uint index) external view returns(address);
    function getCondition(uint index) external view returns(bytes32);
    function getParentCollection(uint index) external view returns(bytes32);
    function createDistributor(
        bytes32 _parentCollection,
        address _collateralToken, 
        uint[] calldata _indexSets,
        uint template_index, 
        uint _question_index 
    ) external returns (address);
}
