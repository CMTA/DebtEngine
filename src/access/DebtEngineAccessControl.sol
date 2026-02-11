// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {AccessControl} from "OZ/access/AccessControl.sol";
import {Context} from "OZ/utils/Context.sol";
import {DebtEngine} from "../DebtEngine.sol";

contract DebtEngineAccessControl is DebtEngine, AccessControl {
    bytes32 public constant CREDIT_EVENTS_MANAGER_ROLE = keccak256("CREDIT_EVENTS_MANAGER_ROLE");
    bytes32 public constant DEBT_MANAGER_ROLE = keccak256("DEBT_MANAGER_ROLE");

    constructor(address admin, address forwarderIrrevocable) DebtEngine(forwarderIrrevocable) {
        if (admin == address(0)) {
            revert AdminWithAddressZeroNotAllowed();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /* ============ AUTHORIZATION HOOKS ============ */

    function _authorizeSetDebt() internal override view {
        _checkRole(DEBT_MANAGER_ROLE);
    }

    function _authorizeSetCreditEvents() internal override view {
        _checkRole(CREDIT_EVENTS_MANAGER_ROLE);
    }

    /* ============ ACCESS CONTROL ============ */

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        // The Default Admin has all roles
        if (AccessControl.hasRole(DEFAULT_ADMIN_ROLE, account)) {
            return true;
        }
        return AccessControl.hasRole(role, account);
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
