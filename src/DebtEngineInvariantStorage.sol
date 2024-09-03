// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

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