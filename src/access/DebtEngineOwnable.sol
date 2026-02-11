// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Ownable} from "OZ/access/Ownable.sol";
import {Context} from "OZ/utils/Context.sol";
import {DebtEngine} from "../DebtEngine.sol";

contract DebtEngineOwnable is DebtEngine, Ownable {
    constructor(address owner, address forwarderIrrevocable) DebtEngine(forwarderIrrevocable) Ownable(owner) {}

    /* ============ AUTHORIZATION HOOKS ============ */

    function _authorizeSetDebt() internal override view {
        _checkOwner();
    }

    function _authorizeSetCreditEvents() internal override view {
        _checkOwner();
    }

    /*//////////////////////////////////////////////////////////////
                           ERC2771
    //////////////////////////////////////////////////////////////*/

    function _msgSender() internal view override(DebtEngine, Context) returns (address sender) {
        return DebtEngine._msgSender();
    }

    function _msgData() internal view override(DebtEngine, Context) returns (bytes calldata) {
        return DebtEngine._msgData();
    }

    function _contextSuffixLength() internal view override(DebtEngine, Context) returns (uint256) {
        return DebtEngine._contextSuffixLength();
    }
}
