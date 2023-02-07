pragma solidity ^0.8.2;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./ICT.sol";
import "./IFixedProductMarketMaker.sol";


interface IFPMMDeterministicFactory {
    function cloneConstructor(bytes calldata consData) external;

    function create2FixedProductMarketMaker(
        uint saltNonce,
        ICT conditionalTokens,
        IERC20 collateralToken,
        bytes32[] calldata conditionIds,
        uint fee,
        uint initialFunds,
        uint[] calldata distributionHint
    )
        external
        returns (IFixedProductMarketMaker);
}
