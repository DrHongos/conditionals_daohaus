// SPDX-License-Identifier: MIT
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.8.0;

interface ICT {

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    function prepareCondition(address oracle, bytes32 questionId, uint outcomeSlotCount) external;
    function getConditionId(address oracle, bytes32 questionId, uint outcomeSlotCount) external returns (bytes32);
    function getOutcomeSlotCount(bytes32) external returns(uint256);
    function splitPosition(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint[] calldata partition,
        uint amount) external;
    function getCollectionId(
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256 indexSet
    ) external returns (bytes32); 
    function getPositionId(
        address collateralToken,
        bytes32 collectionId
    ) external returns (uint256);
    function redeemPositions(
        IERC20 collateralToken, 
        bytes32 parentCollectionId, 
        bytes32 conditionId, 
        uint[] calldata indexSets
    ) external;
   function reportPayouts(bytes32 questionId, uint[] calldata payouts) external;
//-------------------- ERC1155
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}
