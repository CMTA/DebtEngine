// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract  DebtEngineInvariantStorage {
    // CreditEvents
    bytes32 public constant CREDIT_EVENTS_MANAGER_ROLE =
    keccak256("CREDIT_EVENTS_MANAGER_ROLE");

    // DebtModule
    bytes32 public constant DEBT_MANAGER_ROLE = keccak256("DEBT_MANAGER_ROLE");

    // custom error
    error AdminAddressZeroNotAllowed();
    error InvalidInputLength();

}