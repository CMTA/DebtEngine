// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

abstract contract DebtEngineInvariantStorage {
    error AdminWithAddressZeroNotAllowed();
    error BatchSizeTooLarge(uint256 size, uint256 maxSize);
    error InvalidInputLength();
    error SmartContractWithAddressZeroNotAllowed();
}
