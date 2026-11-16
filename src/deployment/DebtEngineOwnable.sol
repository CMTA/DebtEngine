// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Ownable} from "OZ/access/Ownable.sol";
import {ERC2771Context, Context} from "OZ/metatx/ERC2771Context.sol";
import {DebtEngineBase} from "../DebtEngineBase.sol";

contract DebtEngineOwnable is DebtEngineBase, Ownable, ERC2771Context {
    constructor(address owner, address forwarderIrrevocable) ERC2771Context(forwarderIrrevocable) Ownable(owner) {}

    /* ============ AUTHORIZATION HOOKS ============ */

    function _authorizeSetDebt() internal view override {
        _checkOwner();
    }

    function _authorizeSetCreditEvents() internal view override {
        _checkOwner();
    }

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
