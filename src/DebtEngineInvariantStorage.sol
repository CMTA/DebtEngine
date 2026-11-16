// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

abstract contract DebtEngineInvariantStorage {
    error AdminWithAddressZeroNotAllowed();
    error BatchSizeTooLarge(uint256 size, uint256 maxSize);
    error InvalidInputLength();
    error SmartContractWithAddressZeroNotAllowed();
}
