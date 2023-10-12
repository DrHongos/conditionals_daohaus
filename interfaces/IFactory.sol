// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IFactory {
    function getTimeout(bytes32 condition) external view returns(uint);
    function changeTimeOut(bytes32 question_condition, uint _timeout) external;
}
