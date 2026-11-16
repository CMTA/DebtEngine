// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {DebtEngineBaseTest} from "./DebtEngineBase.t.sol";
import {DebtEngineAccessControl} from "../src/deployment/DebtEngineAccessControl.sol";
import {IAccessControl} from "OZ/access/IAccessControl.sol";
import {IAccessControlEnumerable} from "OZ/access/extensions/IAccessControlEnumerable.sol";
import {ICMTATDebt, ICMTATCreditEvents} from "CMTAT/interfaces/tokenization/ICMTAT.sol";

contract DebtEngineAccessControlTest is DebtEngineBaseTest {
    DebtEngineAccessControl private debtEngineAc;

    bytes32 private constant DEBT_MANAGER_ROLE = keccak256("DEBT_MANAGER_ROLE");
    bytes32 private constant CREDIT_EVENTS_MANAGER_ROLE = keccak256("CREDIT_EVENTS_MANAGER_ROLE");

    function _deployEngine() internal override {
        debtEngineAc = new DebtEngineAccessControl(admin, ADDRESS_ZERO);
        debtEngine = debtEngineAc;
    }

    function _expectUnauthorizedDebtRevert(address caller) internal override {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, DEBT_MANAGER_ROLE)
        );
    }

    function _expectUnauthorizedCreditEventsRevert(address caller) internal override {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, CREDIT_EVENTS_MANAGER_ROLE
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
            DEPLOYMENT
    ///////////////////////////////////////*/

    function testDeploy() public override {
        address forwarder = address(0x1);
        debtEngineAc = new DebtEngineAccessControl(admin, forwarder);

        // Forwarder
        assertEq(debtEngineAc.isTrustedForwarder(forwarder), true);
        // admin
        vm.expectRevert(abi.encodeWithSelector(AdminWithAddressZeroNotAllowed.selector));
        new DebtEngineAccessControl(ADDRESS_ZERO, forwarder);
    }

    /*//////////////////////////////////////////////////////////////
              Access control — unauthorized
    ///////////////////////////////////////*/

    function testCannotNonAdminSetDebt() public {
        _expectUnauthorizedDebtRevert(attacker);
        vm.prank(attacker);
        debtEngine.setDebt(testContract, debtSample);
    }

    function testCannotNonAdminSetCreditEvents() public {
        _expectUnauthorizedCreditEventsRevert(attacker);
        vm.prank(attacker);
        debtEngine.setCreditEvents(testContract, creditEventSample);
    }

    function testSetDebtsBatchAsNonAdminFails() public {
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = testContract2;

        ICMTATDebt.DebtInformation[] memory debts = new ICMTATDebt.DebtInformation[](2);
        debts[0] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier1, debtInstrument: debtSample1});
        debts[1] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier2, debtInstrument: debtSample2});

        _expectUnauthorizedDebtRevert(attacker);
        vm.prank(attacker);
        debtEngine.setDebtBatch(contracts, debts);
    }

    function testSetCreditEventsBatchAsNonAdminFails() public {
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = testContract2;

        ICMTATCreditEvents.CreditEvents[] memory creditEventsList = new ICMTATCreditEvents.CreditEvents[](2);
        creditEventsList[0] = creditEventSample1;
        creditEventsList[1] = creditEventSample2;

        _expectUnauthorizedCreditEventsRevert(attacker);
        vm.prank(attacker);
        debtEngine.setCreditEventsBatch(contracts, creditEventsList);
    }

    /*//////////////////////////////////////////////////////////////
              RBAC-specific: role grant/revoke
    ///////////////////////////////////////*/

    function testGrantDebtManagerRole() public {
        bytes32 role = DEBT_MANAGER_ROLE;

        vm.prank(admin);
        debtEngineAc.grantRole(role, attacker);

        vm.prank(attacker);
        debtEngine.setDebt(testContract, debtSample);

        ICMTATDebt.DebtInformation memory d = debtEngine.debt(testContract);
        assertEq(d.debtInstrument.interestRate, 5);
    }

    function testRevokeDebtManagerRole() public {
        bytes32 role = DEBT_MANAGER_ROLE;

        vm.prank(admin);
        debtEngineAc.grantRole(role, attacker);

        vm.prank(admin);
        debtEngineAc.revokeRole(role, attacker);

        _expectUnauthorizedDebtRevert(attacker);
        vm.prank(attacker);
        debtEngine.setDebt(testContract, debtSample);
    }

    function testGrantCreditEventsManagerRole() public {
        bytes32 role = CREDIT_EVENTS_MANAGER_ROLE;

        vm.prank(admin);
        debtEngineAc.grantRole(role, attacker);

        vm.prank(attacker);
        debtEngine.setCreditEvents(testContract, creditEventSample);

        ICMTATCreditEvents.CreditEvents memory credit = debtEngine.creditEvents(testContract);
        assertEq(credit.flagRedeemed, true);
    }

    function testRevokeCreditEventsManagerRole() public {
        bytes32 role = CREDIT_EVENTS_MANAGER_ROLE;

        vm.prank(admin);
        debtEngineAc.grantRole(role, attacker);

        vm.prank(admin);
        debtEngineAc.revokeRole(role, attacker);

        _expectUnauthorizedCreditEventsRevert(attacker);
        vm.prank(attacker);
        debtEngine.setCreditEvents(testContract, creditEventSample);
    }

    /*//////////////////////////////////////////////////////////////
              RBAC-specific: role separation
    ///////////////////////////////////////*/

    function testDebtManagerCannotSetCreditEvents() public {
        vm.prank(admin);
        debtEngineAc.grantRole(DEBT_MANAGER_ROLE, attacker);

        _expectUnauthorizedCreditEventsRevert(attacker);
        vm.prank(attacker);
        debtEngine.setCreditEvents(testContract, creditEventSample);
    }

    function testCreditEventsManagerCannotSetDebt() public {
        vm.prank(admin);
        debtEngineAc.grantRole(CREDIT_EVENTS_MANAGER_ROLE, attacker);

        _expectUnauthorizedDebtRevert(attacker);
        vm.prank(attacker);
        debtEngine.setDebt(testContract, debtSample);
    }

    /*//////////////////////////////////////////////////////////////
              RBAC-specific: enumeration
    ///////////////////////////////////////*/

    function testRoleMembersAreEnumerable() public {
        assertEq(debtEngineAc.getRoleMemberCount(debtEngineAc.DEFAULT_ADMIN_ROLE()), 1);
        assertEq(debtEngineAc.getRoleMember(debtEngineAc.DEFAULT_ADMIN_ROLE(), 0), admin);

        vm.prank(admin);
        debtEngineAc.grantRole(DEBT_MANAGER_ROLE, attacker);
        assertEq(debtEngineAc.getRoleMemberCount(DEBT_MANAGER_ROLE), 1);
        assertEq(debtEngineAc.getRoleMember(DEBT_MANAGER_ROLE, 0), attacker);

        vm.prank(admin);
        debtEngineAc.revokeRole(DEBT_MANAGER_ROLE, attacker);
        assertEq(debtEngineAc.getRoleMemberCount(DEBT_MANAGER_ROLE), 0);
    }

    function testImplicitAdminIsNotEnumerated() public view {
        // The admin passes every hasRole check but is not listed as a role member
        assertTrue(debtEngineAc.hasRole(DEBT_MANAGER_ROLE, admin));
        assertTrue(debtEngineAc.hasRole(CREDIT_EVENTS_MANAGER_ROLE, admin));
        assertEq(debtEngineAc.getRoleMemberCount(DEBT_MANAGER_ROLE), 0);
        assertEq(debtEngineAc.getRoleMemberCount(CREDIT_EVENTS_MANAGER_ROLE), 0);
    }

    function testSupportsInterface() public view {
        assertTrue(debtEngineAc.supportsInterface(type(IAccessControlEnumerable).interfaceId));
        assertTrue(debtEngineAc.supportsInterface(type(IAccessControl).interfaceId));
        assertFalse(debtEngineAc.supportsInterface(0xffffffff));
    }

    function testRoleConstants() public view {
        assertEq(debtEngineAc.DEBT_MANAGER_ROLE(), DEBT_MANAGER_ROLE);
        assertEq(debtEngineAc.CREDIT_EVENTS_MANAGER_ROLE(), CREDIT_EVENTS_MANAGER_ROLE);
    }
}
