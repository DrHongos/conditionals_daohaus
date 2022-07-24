// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "../src/SimpleDistributor.sol";
import "./ICT.sol";

contract User is DSTest, ERC1155Holder {
    IERC20 collateralToken;
    constructor(address _token) {
      collateralToken = IERC20(_token);
    }
    function approveCollateral(address spender, uint256 amount)
        public returns(bool)
    {
        return collateralToken.approve(spender, amount);
    }

///////////////////////////////////////////////////////////////DISTRIBUTOR FUNCTIONS
    // setPosition (update)
    function setProbabilityDistribution(address distributor, uint[] calldata distribution) public {
      return SimpleDistributor(distributor).setProbabilityDistribution(distribution);
    }
    // redeem
    function redeem(address distributor) public {
      return SimpleDistributor(distributor).redeem(); 
    }

////////////////////////////////////////////////////////////////NFTs functions
    function approveERC1155(address contractAddress, address operator) public {
      return IERC1155(contractAddress).setApprovalForAll(operator, true);
    }

    function reportPayouts(address cTAddress, bytes32 questionId, uint[] calldata payouts) public {
      return ICT(cTAddress).reportPayouts(questionId, payouts);
    }

    function redeemPositions(
      address cTAddress,        
      bytes32 parentCollectionId, 
      bytes32 conditionId, 
      uint[] calldata indexSets
      ) public {
      return ICT(cTAddress).redeemPositions(
        collateralToken, 
        parentCollectionId, 
        conditionId, 
        indexSets
      );
    }

}
