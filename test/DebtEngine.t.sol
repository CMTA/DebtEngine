// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DebtEngine} from "../src/DebtEngine.sol";
import {IDebtEngine} from "CMTAT/interfaces/engine/IDebtEngine.sol";
import {ICMTATDebt, ICMTATCreditEvents} from "CMTAT/interfaces/tokenization/ICMTAT.sol";
import {IERC1643CMTAT} from "CMTAT/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {ISnapshotEngine} from "CMTAT/interfaces/engine/ISnapshotEngine.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IERC1643} from "CMTAT/interfaces/tokenization/draft-IERC1643.sol";
import {DebtEngineInvariantStorage} from "../src/DebtEngineInvariantStorage.sol";
import {AccessControl} from "OZ/access/AccessControl.sol";
import {CMTATStandaloneDebt} from "CMTAT/deployment/debt/CMTATStandaloneDebt.sol";
import {ICMTATConstructor} from "CMTAT/interfaces/technical/ICMTATConstructor.sol";
contract DebtEngineTest is
    Test,
    AccessControl,
    DebtEngineInvariantStorage
{
    DebtEngine private debtEngine;
    address private admin = address(0x1);
    address private attacker = address(0x2);
    address private testContract = address(0x3);
    address private testContract1 = address(0x4);
    address private testContract2 = address(0x5);
    address AddressZero = address(0);
    CMTATStandaloneDebt cmtat;

    // Sample data for DebtInformation and CreditEvents
    ICMTATDebt.DebtInformation private debtSample;

    ICMTATCreditEvents.CreditEvents private creditEventSample =
        ICMTATCreditEvents.CreditEvents({flagDefault: false, flagRedeemed: true, rating: "AAA"});

    ICMTATDebt.DebtIdentifier private debtIdentifier1 =
        ICMTATDebt.DebtIdentifier({
            issuerName: "Name",
            issuerDescription: "Description",
            guarantor: "Guarantor A",
            debtHolder: "Bond Holder B"
        });
    // Sample data for DebtInstrument
    ICMTATDebt.DebtInstrument private debtSample1 =
        ICMTATDebt.DebtInstrument({
            interestRate: 5,
            parValue: 1000,
            minimumDenomination: 5000,
            issuanceDate: "2023-01-01",
            maturityDate: "2025-01-01",
            couponPaymentFrequency: "Semi-Annual",
            interestScheduleFormat: "Annual",
            interestPaymentDate: "2024-12-31",
            dayCountConvention: "30/360",
            businessDayConvention: "Modified Following",
            currency: "USDC",
            currencyContract: address(0x3)
    });

    ICMTATDebt.DebtInstrument private debtSample2 =
        ICMTATDebt.DebtInstrument({
            interestRate: 6,
            parValue: 2000,
            minimumDenomination: 0,
            issuanceDate: "2024-01-01",
            maturityDate: "2026-01-01",
            couponPaymentFrequency: "Quarterly",
            interestScheduleFormat: "Monthly",
            interestPaymentDate: "2025-12-31",
            dayCountConvention: "Actual/Actual",
            businessDayConvention: "Following",
            currency: "",
            currencyContract: address(0)
    });
    ICMTATDebt.DebtIdentifier private debtIdentifier2 =
        ICMTATDebt.DebtIdentifier({
            issuerName: "Name2",
            issuerDescription: "Description2",
            guarantor: "Guarantor B",
            debtHolder: "Bond Holder C"
        });

    ICMTATCreditEvents.CreditEvents private creditEventSample1 =
        ICMTATCreditEvents.CreditEvents({flagDefault: false, flagRedeemed: true, rating: "AAA"});

    ICMTATCreditEvents.CreditEvents private creditEventSample2 =
        ICMTATCreditEvents.CreditEvents({flagDefault: true, flagRedeemed: false, rating: "BBB"});

    function setUp() public {
        // Initialize DebtInformation sample
        debtSample = ICMTATDebt.DebtInformation({
            debtIdentifier: debtIdentifier1,
            debtInstrument: debtSample1
        });

        // Deploy the DebtEngine contract with admin role
        debtEngine = new DebtEngine(admin, AddressZero);
        ICMTATConstructor.ERC20Attributes
            memory erc20Attributes = ICMTATConstructor.ERC20Attributes(
                "CMTA Token",
                "CMTAT",
                0
            );
        ICMTATConstructor.BaseModuleAttributes
            memory baseModuleAttributes = ICMTATConstructor
                .BaseModuleAttributes(
                    "CMTAT_ISIN",
                    IERC1643CMTAT.DocumentInfo("terms", "https://cmta.ch", bytes32(0)),
                    "CMTAT_info"
                );
        ICMTATConstructor.Engine memory engines = ICMTATConstructor.Engine(
            IRuleEngine(AddressZero),
            ISnapshotEngine(AddressZero),
            IERC1643(AddressZero)
        );
        cmtat = new CMTATStandaloneDebt(
            admin,
            erc20Attributes,
            baseModuleAttributes,
            engines
        );
    }

    /*//////////////////////////////////////////////////////////////
            DEPLOYMENT
    ///////////////////////////////////////*/

    function testDeploy() public {
        address forwarder = address(0x1);
        debtEngine = new DebtEngine(admin, forwarder);

        // Forwarder
        assertEq(debtEngine.isTrustedForwarder(forwarder), true);
        // admin
        vm.expectRevert(
            abi.encodeWithSelector(AdminWithAddressZeroNotAllowed.selector)
        );
        debtEngine = new DebtEngine(AddressZero, forwarder);
    }

    /*//////////////////////////////////////////////////////////////
              Access control
    ///////////////////////////////////////*/

    function testSetDebtAsAdmin() public {
        // Act
        // Call as admin
        vm.prank(admin);
        debtEngine.setDebt(testContract, debtSample);

        // Assert
        //  Verify that debt was set correctly
        ICMTATDebt.DebtInformation memory debt = debtEngine.debt(testContract);
        assertEq(debt.debtInstrument.interestRate, 5);
        assertEq(debt.debtInstrument.parValue, 1000);
    }

    function testCannotNonAdminSetDebt() public {
        // Attempt to set debt as non-admin
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                attacker,
                DEBT_MANAGER_ROLE
            )
        );
        debtEngine.setDebt(testContract, debtSample);
    }

    function testCanAdminSetCreditEvents() public {
        // Call as admin
        vm.prank(admin);
        debtEngine.setCreditEvents(testContract, creditEventSample);

        // Act
        // Verify that credit events were set correctly
        ICMTATCreditEvents.CreditEvents memory credit = debtEngine.creditEvents(
            testContract
        );
        assertEq(credit.flagDefault, false);
        assertEq(credit.flagRedeemed, true);
        assertEq(credit.rating, "AAA");
    }

    function testCannotNonAdminSetCreditEvents() public {
        // Act
        // Attempt to set credit events as non-admin
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                attacker,
                CREDIT_EVENTS_MANAGER_ROLE
            )
        );
        debtEngine.setCreditEvents(testContract, creditEventSample);
    }

    function testSetDebtsBatchAsAdmin() public {
        // Call as admin to set multiple debts
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = testContract2;

        ICMTATDebt.DebtInformation[] memory debts = new ICMTATDebt.DebtInformation[](2);
        debts[0] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier1, debtInstrument: debtSample1});
        debts[1] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier2, debtInstrument: debtSample2});

        vm.prank(admin);
        debtEngine.setDebtBatch(contracts, debts);

        // Verify that both debts were set correctly
        ICMTATDebt.DebtInformation memory debt1 = debtEngine.debt(testContract1);
        assertEq(debt1.debtInstrument.interestRate, 5);
        assertEq(debt1.debtInstrument.parValue, 1000);

        ICMTATDebt.DebtInformation memory debt2 = debtEngine.debt(testContract2);
        assertEq(debt2.debtInstrument.interestRate, 6);
        assertEq(debt2.debtInstrument.parValue, 2000);
    }

    function testSetDebtsBatchAsNonAdminFails() public {
        // Attempt to set multiple debts as non-admin
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = testContract2;

        ICMTATDebt.DebtInformation[] memory debts = new ICMTATDebt.DebtInformation[](2);
        debts[0] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier1, debtInstrument: debtSample1});
        debts[1] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier2, debtInstrument: debtSample2});

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                attacker,
                DEBT_MANAGER_ROLE
            )
        );
        debtEngine.setDebtBatch(contracts, debts);
    }

    function testSetCreditEventsBatchAsAdmin() public {
        // Call as admin to set multiple credit events
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = testContract2;

        ICMTATCreditEvents.CreditEvents[]
            memory creditEventsList = new ICMTATCreditEvents.CreditEvents[](2);
        creditEventsList[0] = creditEventSample1;
        creditEventsList[1] = creditEventSample2;

        vm.prank(admin);
        debtEngine.setCreditEventsBatch(contracts, creditEventsList);

        // Verify that both credit events were set correctly
        ICMTATCreditEvents.CreditEvents memory credit1 = debtEngine.creditEvents(
            testContract1
        );
        assertEq(credit1.flagDefault, false);
        assertEq(credit1.rating, "AAA");

        ICMTATCreditEvents.CreditEvents memory credit2 = debtEngine.creditEvents(
            testContract2
        );
        assertEq(credit2.flagDefault, true);
        assertEq(credit2.rating, "BBB");
    }

    function testSetCreditEventsBatchAsNonAdminFails() public {
        // Attempt to set multiple credit events as non-admin
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = testContract2;

        ICMTATCreditEvents.CreditEvents[]
            memory creditEventsList = new ICMTATCreditEvents.CreditEvents[](2);
        creditEventsList[0] = creditEventSample1;
        creditEventsList[1] = creditEventSample2;

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                attacker,
                CREDIT_EVENTS_MANAGER_ROLE
            )
        );
        debtEngine.setCreditEventsBatch(contracts, creditEventsList);
    }

    /*//////////////////////////////////////////////////////////////
            Get
    ///////////////////////////////////////*/

    function testCanReturnCMTATDebt() public {
        // Arrange
        vm.prank(admin);
        debtEngine.setDebt(address(cmtat), debtSample);

        vm.prank(admin);
        cmtat.setDebtEngine(debtEngine);

        // Call from CMTAT, return debt smart contract
        ICMTATDebt.DebtInformation memory debt = cmtat.debt();
        assertEq(debt.debtInstrument.parValue, 1000);
    }

    function testCanReturnCMTATCreditEvents() public {
        // Call as admin to set credit events for non-admin's contract
        vm.prank(admin);
        debtEngine.setCreditEvents(address(cmtat), creditEventSample);

        vm.prank(admin);
        cmtat.setDebtEngine(debtEngine);

        // Call from attacker, should return credit events for attacker address
        vm.prank(attacker);
        ICMTATCreditEvents.CreditEvents memory credit = cmtat.creditEvents();
        assertEq(credit.flagRedeemed, true);
    }

    /*//////////////////////////////////////////////////////////////
           INVALID PARAMETER
    ///////////////////////////////////////*/
    function testSetDebtsBatchLengthMismatch() public {
        // Set arrays with mismatched lengths
        address[] memory contracts = new address[](1);
        contracts[0] = testContract1;

        ICMTATDebt.DebtInformation[] memory debts = new ICMTATDebt.DebtInformation[](2);
        debts[0] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier1, debtInstrument: debtSample1});
        debts[1] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier2, debtInstrument: debtSample2});

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(InvalidInputLength.selector));
        debtEngine.setDebtBatch(contracts, debts);
    }

    function testSetCreditEventsBatchLengthMismatch() public {
        // Set arrays with mismatched lengths
        address[] memory contracts = new address[](1);
        contracts[0] = testContract1;

        ICMTATCreditEvents.CreditEvents[]
            memory creditEventsList = new ICMTATCreditEvents.CreditEvents[](2);
        creditEventsList[0] = creditEventSample1;
        creditEventsList[1] = creditEventSample2;

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(InvalidInputLength.selector));
        debtEngine.setCreditEventsBatch(contracts, creditEventsList);
    }

    function testCannotSetDebtForAddressZero() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(SmartContractWithAddressZeroNotAllowed.selector)
        );
        debtEngine.setDebt(AddressZero, debtSample);
    }

    function testCannotSetCreditEventsForAddressZero() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(SmartContractWithAddressZeroNotAllowed.selector)
        );
        debtEngine.setCreditEvents(AddressZero, creditEventSample);
    }

    function testCannotSetDebtBatchWithAddressZero() public {
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = AddressZero;

        ICMTATDebt.DebtInformation[] memory debts = new ICMTATDebt.DebtInformation[](2);
        debts[0] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier1, debtInstrument: debtSample1});
        debts[1] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier2, debtInstrument: debtSample2});

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(SmartContractWithAddressZeroNotAllowed.selector)
        );
        debtEngine.setDebtBatch(contracts, debts);
    }

    function testCannotSetCreditEventsBatchWithAddressZero() public {
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = AddressZero;

        ICMTATCreditEvents.CreditEvents[]
            memory creditEventsList = new ICMTATCreditEvents.CreditEvents[](2);
        creditEventsList[0] = creditEventSample1;
        creditEventsList[1] = creditEventSample2;

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(SmartContractWithAddressZeroNotAllowed.selector)
        );
        debtEngine.setCreditEventsBatch(contracts, creditEventsList);
    }

    /*//////////////////////////////////////////////////////////////
           EVENTS
    ///////////////////////////////////////*/

    function testSetDebtEmitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit DebtEngine.DebtSet(testContract);
        debtEngine.setDebt(testContract, debtSample);
    }

    function testSetCreditEventsEmitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit DebtEngine.CreditEventsSet(testContract);
        debtEngine.setCreditEvents(testContract, creditEventSample);
    }

    function testSetDebtBatchEmitsEvents() public {
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = testContract2;

        ICMTATDebt.DebtInformation[] memory debts = new ICMTATDebt.DebtInformation[](2);
        debts[0] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier1, debtInstrument: debtSample1});
        debts[1] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier2, debtInstrument: debtSample2});

        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit DebtEngine.DebtSet(testContract1);
        vm.expectEmit(true, false, false, false);
        emit DebtEngine.DebtSet(testContract2);
        debtEngine.setDebtBatch(contracts, debts);
    }

    function testSetCreditEventsBatchEmitsEvents() public {
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = testContract2;

        ICMTATCreditEvents.CreditEvents[]
            memory creditEventsList = new ICMTATCreditEvents.CreditEvents[](2);
        creditEventsList[0] = creditEventSample1;
        creditEventsList[1] = creditEventSample2;

        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit DebtEngine.CreditEventsSet(testContract1);
        vm.expectEmit(true, false, false, false);
        emit DebtEngine.CreditEventsSet(testContract2);
        debtEngine.setCreditEventsBatch(contracts, creditEventsList);
    }
}
