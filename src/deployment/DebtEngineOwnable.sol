// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Ownable} from "OZ/access/Ownable.sol";
import {Ownable2Step} from "OZ/access/Ownable2Step.sol";
import {ERC2771Context, Context} from "OZ/metatx/ERC2771Context.sol";
import {DebtEngineBase} from "../DebtEngineBase.sol";

/**
 * @notice DebtEngine deployment where a single owner manages both debt and credit events.
 * @dev Ownership transfer is two-step (`transferOwnership` then `acceptOwnership` by the new owner).
 * Every authorization hook collapses to `onlyOwner`, so this variant cannot separate duties.
 */
contract DebtEngineOwnable is DebtEngineBase, Ownable2Step, ERC2771Context {
    constructor(address owner, address forwarderIrrevocable) ERC2771Context(forwarderIrrevocable) Ownable(owner) {}

    /* ============ AUTHORIZATION HOOKS ============ */

    function _authorizeSetDebt() internal view virtual override onlyOwner {}

    function _authorizeSetCreditEvents() internal view virtual override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                           ERC2771
    //////////////////////////////////////////////////////////////*/

    function _msgSender() internal view override(DebtEngineBase, ERC2771Context, Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    function _contextSuffixLength() internal view override(ERC2771Context, Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}
