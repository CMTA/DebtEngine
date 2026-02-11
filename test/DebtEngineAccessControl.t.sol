// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {DebtEngineBaseTest} from "./DebtEngineBase.t.sol";
import {DebtEngineAccessControl} from "../src/access/DebtEngineAccessControl.sol";
import {IAccessControl} from "OZ/access/IAccessControl.sol";
import {ICMTATDebt, ICMTATCreditEvents} from "CMTAT/interfaces/tokenization/ICMTAT.sol";

contract DebtEngineAccessControlTest is DebtEngineBaseTest {
    DebtEngineAccessControl private debtEngineAC;

    bytes32 private DEBT_MANAGER_ROLE;
    bytes32 private CREDIT_EVENTS_MANAGER_ROLE;

    function _deployEngine() internal override {
        debtEngineAC = new DebtEngineAccessControl(admin, AddressZero);
        debtEngine = debtEngineAC;
        DEBT_MANAGER_ROLE = debtEngineAC.DEBT_MANAGER_ROLE();
        CREDIT_EVENTS_MANAGER_ROLE = debtEngineAC.CREDIT_EVENTS_MANAGER_ROLE();
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
        debtEngineAC = new DebtEngineAccessControl(admin, forwarder);

        // Forwarder
        assertEq(debtEngineAC.isTrustedForwarder(forwarder), true);
        // admin
        vm.expectRevert(abi.encodeWithSelector(AdminWithAddressZeroNotAllowed.selector));
        new DebtEngineAccessControl(AddressZero, forwarder);
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
        debtEngineAC.grantRole(role, attacker);

        vm.prank(attacker);
        debtEngine.setDebt(testContract, debtSample);

        ICMTATDebt.DebtInformation memory d = debtEngine.debt(testContract);
        assertEq(d.debtInstrument.interestRate, 5);
    }

    function testRevokeDebtManagerRole() public {
        bytes32 role = DEBT_MANAGER_ROLE;

        vm.prank(admin);
        debtEngineAC.grantRole(role, attacker);

        vm.prank(admin);
        debtEngineAC.revokeRole(role, attacker);

        _expectUnauthorizedDebtRevert(attacker);
        vm.prank(attacker);
        debtEngine.setDebt(testContract, debtSample);
    }

    function testGrantCreditEventsManagerRole() public {
        bytes32 role = CREDIT_EVENTS_MANAGER_ROLE;

        vm.prank(admin);
        debtEngineAC.grantRole(role, attacker);

        vm.prank(attacker);
        debtEngine.setCreditEvents(testContract, creditEventSample);

        ICMTATCreditEvents.CreditEvents memory credit = debtEngine.creditEvents(testContract);
        assertEq(credit.flagRedeemed, true);
    }

    function testRevokeCreditEventsManagerRole() public {
        bytes32 role = CREDIT_EVENTS_MANAGER_ROLE;

        vm.prank(admin);
        debtEngineAC.grantRole(role, attacker);

        vm.prank(admin);
        debtEngineAC.revokeRole(role, attacker);

        _expectUnauthorizedCreditEventsRevert(attacker);
        vm.prank(attacker);
        debtEngine.setCreditEvents(testContract, creditEventSample);
    }
}
