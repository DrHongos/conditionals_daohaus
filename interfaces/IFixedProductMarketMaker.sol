pragma solidity ^0.8.2;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./ICT.sol";

interface IFixedProductMarketMaker {
    event FPMMFundingAdded(
        address indexed funder,
        uint[] amountsAdded,
        uint sharesMinted
    );
    event FPMMFundingRemoved(
        address indexed funder,
        uint[] amountsRemoved,
        uint collateralRemovedFromFeePool,
        uint sharesBurnt
    );
    event FPMMBuy(
        address indexed buyer,
        uint investmentAmount,
        uint feeAmount,
        uint indexed outcomeIndex,
        uint outcomeTokensBought
    );
    event FPMMSell(
        address indexed seller,
        uint returnAmount,
        uint feeAmount,
        uint indexed outcomeIndex,
        uint outcomeTokensSold
    );

    function collectedFees() external view returns (uint);

    function feesWithdrawableBy(address account) external view returns (uint);

    function withdrawFees(address account) external;

    function addFunding(uint addedFunds, uint[] calldata distributionHint) external;

    function removeFunding(uint sharesToBurn) external;

    function calcBuyAmount(uint investmentAmount, uint outcomeIndex) external view returns (uint);

    function calcSellAmount(uint returnAmount, uint outcomeIndex) external view returns (uint outcomeTokenSellAmount);

    function buy(uint investmentAmount, uint outcomeIndex, uint minOutcomeTokensToBuy) external;

    function sell(uint returnAmount, uint outcomeIndex, uint maxOutcomeTokensToSell) external;
}

