// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {AccessControl, IAccessControl} from "OZ/access/AccessControl.sol";
import {AccessControlEnumerable} from "OZ/access/extensions/AccessControlEnumerable.sol";
import {ERC2771Context, Context} from "OZ/metatx/ERC2771Context.sol";
import {DebtEngineBase} from "../DebtEngineBase.sol";

/**
 * @notice DebtEngine deployment with role-based access control.
 * @dev Uses `AccessControlEnumerable` so role holders can be listed on-chain.
 * `DEBT_MANAGER_ROLE` gates debt changes, `CREDIT_EVENTS_MANAGER_ROLE` gates credit-events changes.
 */
contract DebtEngineAccessControl is DebtEngineBase, AccessControlEnumerable, ERC2771Context {
    bytes32 public constant CREDIT_EVENTS_MANAGER_ROLE = keccak256("CREDIT_EVENTS_MANAGER_ROLE");
    bytes32 public constant DEBT_MANAGER_ROLE = keccak256("DEBT_MANAGER_ROLE");

    constructor(address admin, address forwarderIrrevocable) ERC2771Context(forwarderIrrevocable) {
        require(admin != address(0), AdminWithAddressZeroNotAllowed());
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /* ============ AUTHORIZATION HOOKS ============ */

    function _authorizeSetDebt() internal view virtual override onlyRole(DEBT_MANAGER_ROLE) {}

    function _authorizeSetCreditEvents() internal view virtual override onlyRole(CREDIT_EVENTS_MANAGER_ROLE) {}

    /* ============ ACCESS CONTROL ============ */

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     *
     * NOTE: The `DEFAULT_ADMIN_ROLE` is treated as a super-admin role.
     * Any account holding `DEFAULT_ADMIN_ROLE` is considered to hold every role,
     * even if it was not explicitly granted via `grantRole`.
     * This means `hasRole(ANY_ROLE, admin)` returns `true` for the admin.
     * `getRoleMember`, `getRoleMemberCount` and `getRoleMembers` will NOT reflect
     * this implicit membership: the admin is not listed as a holder of the other roles.
     * Because OpenZeppelin's `_grantRole` / `_revokeRole` consult this function, granting a role to an admin
     * is a no-op, and revoking or renouncing one emits `RoleRevoked` while the admin keeps the power.
     */
    function hasRole(bytes32 role, address account)
        public
        view
        virtual
        override(AccessControl, IAccessControl)
        returns (bool)
    {
        // The Default Admin has all roles
        if (AccessControl.hasRole(DEFAULT_ADMIN_ROLE, account)) {
            return true;
        }
        return AccessControl.hasRole(role, account);
    }

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
