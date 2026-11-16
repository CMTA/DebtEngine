// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Ownable} from "OZ/access/Ownable.sol";
import {Ownable2Step} from "OZ/access/Ownable2Step.sol";
import {ERC2771Context, Context} from "OZ/metatx/ERC2771Context.sol";
import {ERC165} from "OZ/utils/introspection/ERC165.sol";
import {DebtEngineBase} from "../DebtEngineBase.sol";

/**
 * @notice DebtEngine deployment where a single owner manages both debt and credit events.
 * @dev Ownership transfer is two-step (`transferOwnership` then `acceptOwnership` by the new owner).
 * Every authorization hook collapses to `onlyOwner`, so this variant cannot separate duties.
 * Advertises ERC-173 (contract ownership) through ERC-165.
 */
contract DebtEngineOwnable is DebtEngineBase, Ownable2Step, ERC2771Context, ERC165 {
    /// @dev ERC-165 identifier of the ERC-173 interface (`owner()` ^ `transferOwnership(address)`).
    bytes4 private constant ERC173_INTERFACE_ID = 0x7f5828d0;

    constructor(address owner, address forwarderIrrevocable) ERC2771Context(forwarderIrrevocable) Ownable(owner) {}

    /* ============ ERC-165 ============ */

    /**
     * @inheritdoc ERC165
     * @dev Returns true for ERC-173 and ERC-165.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == ERC173_INTERFACE_ID || super.supportsInterface(interfaceId);
    }

    /* ============ AUTHORIZATION HOOKS ============ */

    function _authorizeSetDebt() internal view virtual override onlyOwner {}

    function _authorizeSetCreditEvents() internal view virtual override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                           ERC2771
    //////////////////////////////////////////////////////////////*/

    function _msgSender() internal view virtual override(DebtEngineBase, ERC2771Context, Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view virtual override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    function _contextSuffixLength() internal view virtual override(ERC2771Context, Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}
