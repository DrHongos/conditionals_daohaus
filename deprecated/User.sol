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

///////////////////////////////////////////////////////////////FACTORY FUNCTIONS
    function createDistributor(
        address factory,
        bytes32 _parentCollection,
        address _collateralToken, 
        uint[] calldata _indexSets,
        uint template_index, 
        uint _question_index 
    ) public returns (address) {
      return IQuestionFactory(factory).createDistributor(
        _parentCollection,
        _collateralToken, 
        _indexSets,
        template_index, 
        _question_index 
      );

    }



///////////////////////////////////////////////////////////////DISTRIBUTOR FUNCTIONS

    function configure(
      address distributor,
      uint amountToSplit, 
      uint timeOut,
      uint price,
      uint fee
    ) public {
      return SimpleDistributor(distributor).configure(
        amountToSplit, 
        timeOut,
        price,
        fee
      );
    }

/*     function closeDistributor(address distributor) public {
      return SimpleDistributor(distributor).close();
    }
 */
/*     function redemptionTime(address distributor) public {
      return SimpleDistributor(distributor).redemptionTime();
    }
 */
    // setPosition (update)
    function setProbabilityDistribution(
      address distributor, 
      uint amount, 
      uint[] calldata distribution, 
      string calldata justification
    ) public {
      return SimpleDistributor(distributor).setProbabilityDistribution(amount, distribution, justification);
    }
    // redeem
    function redeem(address distributor) public {
      return SimpleDistributor(distributor).redeem(); 
    }

    function reportPayouts(address cTAddress, bytes32 questionId, uint[] calldata payouts) public {
      return ICT(cTAddress).reportPayouts(questionId, payouts);
    }

    function changeTimeOut(address distributor, uint timeout) public {
      return SimpleDistributor(distributor).changeTimeOut(timeout);
    }

    function checkQuestion(address distributor) public {
      return SimpleDistributor(distributor).checkQuestion();
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
////////////////////////////////////////////////////////////////NFTs functions
    function approveERC1155(address contractAddress, address operator) public {
      return IERC1155(contractAddress).setApprovalForAll(operator, true);
    }


}
