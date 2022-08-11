// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../interfaces/ISimpleDistributor.sol";
import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract SimpleDistributorFactory is Ownable {
    address public template;

    mapping(uint256 => address) private distributors;
    uint256 public distributorsCount;

    event DistributorCreated(address distributorAddress, uint256 distributorIndex);
    event DistributorTemplateChanged(address _newTemplate);

    constructor(address _template) {
        template = _template;
    }

    function createDistributor()
        external
        returns (address newDistributorAddress)
    {
        newDistributorAddress = Clones.clone(template);
        uint256 newIndex = distributorsCount;
        distributors[newIndex] = newDistributorAddress;
        distributorsCount += 1;
//        ISimpleDistributor(newDistributorAddress).initialize(
//            bytes32 _conditionId,
//            bytes32 parentCollection,
//            IERC20 _collateralToken,
//            uint[] calldata _indexSets,
//            uint _amountToSplit,
//            uint _timeOut
//        );
///////////
// if i do this, the owner of the distributor is this contract
// so i should do the initialization directly to the clone
        emit DistributorCreated(newDistributorAddress, newIndex);
    }

    function changeTemplate(address _newTemplate)
        external
        onlyOwner
    {
        template = _newTemplate;
        emit DistributorTemplateChanged(_newTemplate);
    }
    ///////////////////////////////////////////////////VIEW FUNCTIONS
    function getDistributorAddress(uint256 _index) external view returns (address) {
        return distributors[_index];
    }

}
