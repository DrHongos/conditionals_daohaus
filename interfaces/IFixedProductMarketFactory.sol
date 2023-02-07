pragma solidity ^0.8.2;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./ICT.sol";
import "./IFixedProductMarketMaker.sol";

interface IFixedProductMarketFactory {

    function createFixedProductMarketMaker(
        ICT conditionalTokens,
        IERC20 collateralToken,
        bytes32[] calldata conditionIds,
        uint fee
    ) external returns (IFixedProductMarketMaker);

}
