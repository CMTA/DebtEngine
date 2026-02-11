// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {DebtEngineBaseTest} from "./DebtEngineBase.t.sol";
import {DebtEngineOwnable} from "../src/access/DebtEngineOwnable.sol";
import {Ownable} from "OZ/access/Ownable.sol";
import {ICMTATDebt, ICMTATCreditEvents} from "CMTAT/interfaces/tokenization/ICMTAT.sol";

contract DebtEngineOwnableTest is DebtEngineBaseTest {
    DebtEngineOwnable private debtEngineOwn;

    function _deployEngine() internal override {
        debtEngineOwn = new DebtEngineOwnable(admin, AddressZero);
        debtEngine = debtEngineOwn;
    }

    function _expectUnauthorizedDebtRevert(address caller) internal override {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    }

    function _expectUnauthorizedCreditEventsRevert(address caller) internal override {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    }

    /*//////////////////////////////////////////////////////////////
            DEPLOYMENT
    ///////////////////////////////////////*/

    function testDeploy() public override {
        address forwarder = address(0x1);
        debtEngineOwn = new DebtEngineOwnable(admin, forwarder);

        // Forwarder
        assertEq(debtEngineOwn.isTrustedForwarder(forwarder), true);
        // owner
        assertEq(debtEngineOwn.owner(), admin);
        // zero address
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, AddressZero));
        new DebtEngineOwnable(AddressZero, forwarder);
    }

    /*//////////////////////////////////////////////////////////////
              Access control — unauthorized
    ///////////////////////////////////////*/

    function testCannotNonOwnerSetDebt() public {
        vm.prank(attacker);
        _expectUnauthorizedDebtRevert(attacker);
        debtEngine.setDebt(testContract, debtSample);
    }

    function testCannotNonOwnerSetCreditEvents() public {
        vm.prank(attacker);
        _expectUnauthorizedCreditEventsRevert(attacker);
        debtEngine.setCreditEvents(testContract, creditEventSample);
    }

    function testSetDebtsBatchAsNonOwnerFails() public {
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = testContract2;

        ICMTATDebt.DebtInformation[] memory debts = new ICMTATDebt.DebtInformation[](2);
        debts[0] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier1, debtInstrument: debtSample1});
        debts[1] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier2, debtInstrument: debtSample2});

        vm.prank(attacker);
        _expectUnauthorizedDebtRevert(attacker);
        debtEngine.setDebtBatch(contracts, debts);
    }

    function testSetCreditEventsBatchAsNonOwnerFails() public {
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = testContract2;

        ICMTATCreditEvents.CreditEvents[] memory creditEventsList = new ICMTATCreditEvents.CreditEvents[](2);
        creditEventsList[0] = creditEventSample1;
        creditEventsList[1] = creditEventSample2;

        vm.prank(attacker);
        _expectUnauthorizedCreditEventsRevert(attacker);
        debtEngine.setCreditEventsBatch(contracts, creditEventsList);
    }

    /*//////////////////////////////////////////////////////////////
              Ownable-specific: transferOwnership, renounceOwnership
    ///////////////////////////////////////*/

    function testTransferOwnership() public {
        address newOwner = address(0x99);

        vm.prank(admin);
        debtEngineOwn.transferOwnership(newOwner);
        assertEq(debtEngineOwn.owner(), newOwner);

        // New owner can set debt
        vm.prank(newOwner);
        debtEngine.setDebt(testContract, debtSample);

        ICMTATDebt.DebtInformation memory d = debtEngine.debt(testContract);
        assertEq(d.debtInstrument.interestRate, 5);

        // Old owner can no longer set debt
        vm.prank(admin);
        _expectUnauthorizedDebtRevert(admin);
        debtEngine.setDebt(testContract, debtSample);
    }

    function testRenounceOwnership() public {
        vm.prank(admin);
        debtEngineOwn.renounceOwnership();
        assertEq(debtEngineOwn.owner(), AddressZero);

        // No one can set debt anymore
        vm.prank(admin);
        _expectUnauthorizedDebtRevert(admin);
        debtEngine.setDebt(testContract, debtSample);
    }
}
