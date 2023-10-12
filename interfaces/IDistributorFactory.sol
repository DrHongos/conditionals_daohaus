// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IDistributorFactory {
    function distributorParent(address) external view returns (bytes32);
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
