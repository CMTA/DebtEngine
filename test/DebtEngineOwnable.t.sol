// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {DebtEngineBaseTest} from "./DebtEngineBase.t.sol";
import {DebtEngineBase} from "../src/DebtEngineBase.sol";
import {IERC165} from "OZ/utils/introspection/IERC165.sol";

/// @dev ERC-173 as declared in the standard, to compute its interface id independently.
interface IERC173 {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function owner() external view returns (address);

    function transferOwnership(address newOwner) external;
}
import {DebtEngineOwnable} from "../src/deployment/DebtEngineOwnable.sol";
import {Ownable} from "OZ/access/Ownable.sol";
import {ICMTATDebt, ICMTATCreditEvents} from "CMTAT/interfaces/tokenization/ICMTAT.sol";

contract DebtEngineOwnableTest is DebtEngineBaseTest {
    DebtEngineOwnable private debtEngineOwn;

    function _deployEngine() internal override {
        debtEngineOwn = new DebtEngineOwnable(admin, ADDRESS_ZERO);
        debtEngine = debtEngineOwn;
    }

    function _deployEngineWithForwarder(address forwarder) internal override returns (DebtEngineBase engine) {
        DebtEngineOwnable e = new DebtEngineOwnable(admin, forwarder);
        engine = e;
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
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, ADDRESS_ZERO));
        new DebtEngineOwnable(ADDRESS_ZERO, forwarder);
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

    function testTransferOwnershipIsTwoStep() public {
        address newOwner = address(0x99);

        vm.prank(admin);
        debtEngineOwn.transferOwnership(newOwner);

        // Step 1 only proposes: control has not moved yet
        assertEq(debtEngineOwn.owner(), admin);
        assertEq(debtEngineOwn.pendingOwner(), newOwner);

        vm.prank(newOwner);
        _expectUnauthorizedDebtRevert(newOwner);
        debtEngine.setDebt(testContract, debtSample);

        // Step 2: the pending owner accepts
        vm.prank(newOwner);
        debtEngineOwn.acceptOwnership();
        assertEq(debtEngineOwn.owner(), newOwner);
        assertEq(debtEngineOwn.pendingOwner(), ADDRESS_ZERO);

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

    function testOnlyPendingOwnerCanAcceptOwnership() public {
        vm.prank(admin);
        debtEngineOwn.transferOwnership(address(0x99));

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        debtEngineOwn.acceptOwnership();
        assertEq(debtEngineOwn.owner(), admin);
    }

    function testRenounceOwnership() public {
        vm.prank(admin);
        debtEngineOwn.renounceOwnership();
        assertEq(debtEngineOwn.owner(), ADDRESS_ZERO);

        // No one can set debt anymore
        vm.prank(admin);
        _expectUnauthorizedDebtRevert(admin);
        debtEngine.setDebt(testContract, debtSample);
    }

    /*//////////////////////////////////////////////////////////////
              ERC-165 / ERC-173
    ///////////////////////////////////////*/

    function testSupportsInterface() public view {
        assertEq(type(IERC173).interfaceId, bytes4(0x7f5828d0));
        assertTrue(debtEngineOwn.supportsInterface(type(IERC173).interfaceId));
        assertTrue(debtEngineOwn.supportsInterface(type(IERC165).interfaceId));
        assertFalse(debtEngineOwn.supportsInterface(0xffffffff));
    }

    // ERC-173 says transferOwnership(address(0)) renounces; under Ownable2Step it only cancels a pending transfer
    function testTransferOwnershipToZeroCancelsPendingTransfer() public {
        vm.startPrank(admin);
        debtEngineOwn.transferOwnership(address(0x99));
        debtEngineOwn.transferOwnership(ADDRESS_ZERO);
        vm.stopPrank();

        assertEq(debtEngineOwn.owner(), admin);
        assertEq(debtEngineOwn.pendingOwner(), ADDRESS_ZERO);
    }

    function testOwnershipTransferredEmittedAtDeployment() public {
        vm.expectEmit(true, true, false, false);
        emit IERC173.OwnershipTransferred(ADDRESS_ZERO, admin);
        new DebtEngineOwnable(admin, ADDRESS_ZERO);
    }
}
