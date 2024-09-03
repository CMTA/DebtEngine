// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DebtEngine.sol";
import "CMTAT/interfaces/engine/IDebtEngine.sol";
import {IDebtGlobal} from "CMTAT/interfaces/IDebtGlobal.sol";
import "../src/DebtEngineInvariantStorage.sol";
import "OZ/access/AccessControl.sol";
import "CMTAT/CMTAT_STANDALONE.sol";
contract DebtEngineTest is
    Test,
    AccessControl,
    IDebtGlobal,
    DebtEngineInvariantStorage
{
    DebtEngine private debtEngine;
    address private admin = address(0x1);
    address private attacker = address(0x2);
    address private testContract = address(0x3);
    address private testContract1 = address(0x4);
    address private testContract2 = address(0x5);
    address AddressZero = address(0);
    CMTAT_STANDALONE cmtat;

    // Sample data for DebtBase and CreditEvents
    DebtEngine.DebtBase private debtSample =
        DebtBase({
            interestRate: 5,
            parValue: 1000,
            guarantor: "Guarantor A",
            bondHolder: "Bond Holder B",
            maturityDate: "2025-01-01",
            interestScheduleFormat: "Annual",
            interestPaymentDate: "2024-12-31",
            dayCountConvention: "30/360",
            businessDayConvention: "Modified Following",
            publicHolidaysCalendar: "US",
            issuanceDate: "2023-01-01",
            couponFrequency: "Semi-Annual"
        });

    DebtEngine.CreditEvents private creditEventSample =
        CreditEvents({flagDefault: false, flagRedeemed: true, rating: "AAA"});

    // Sample data for DebtBase and CreditEvents
    DebtEngine.DebtBase private debtSample1 =
        DebtBase({
            interestRate: 5,
            parValue: 1000,
            guarantor: "Guarantor A",
            bondHolder: "Bond Holder B",
            maturityDate: "2025-01-01",
            interestScheduleFormat: "Annual",
            interestPaymentDate: "2024-12-31",
            dayCountConvention: "30/360",
            businessDayConvention: "Modified Following",
            publicHolidaysCalendar: "US",
            issuanceDate: "2023-01-01",
            couponFrequency: "Semi-Annual"
        });

    DebtEngine.DebtBase private debtSample2 =
        DebtBase({
            interestRate: 6,
            parValue: 2000,
            guarantor: "Guarantor B",
            bondHolder: "Bond Holder C",
            maturityDate: "2026-01-01",
            interestScheduleFormat: "Monthly",
            interestPaymentDate: "2025-12-31",
            dayCountConvention: "Actual/Actual",
            businessDayConvention: "Following",
            publicHolidaysCalendar: "UK",
            issuanceDate: "2024-01-01",
            couponFrequency: "Quarterly"
        });

    DebtEngine.CreditEvents private creditEventSample1 =
        CreditEvents({flagDefault: false, flagRedeemed: true, rating: "AAA"});

    DebtEngine.CreditEvents private creditEventSample2 =
        CreditEvents({flagDefault: true, flagRedeemed: false, rating: "BBB"});

    function setUp() public {
        // Deploy the DebtEngine contract with admin role
        debtEngine = new DebtEngine(admin);
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
                    "https://cmta.ch",
                    "CMTAT_info"
                );
        ICMTATConstructor.Engine memory engines = ICMTATConstructor.Engine(
            IRuleEngine(AddressZero),
            IDebtEngine(AddressZero),
            IAuthorizationEngine(AddressZero),
            IERC1643(AddressZero)
        );
        cmtat = new CMTAT_STANDALONE(
            AddressZero,
            admin,
            erc20Attributes,
            baseModuleAttributes,
            engines
        );
    }

    function testSetDebtAsAdmin() public {
        // Act
        // Call as admin
        vm.prank(admin);
        debtEngine.setDebt(testContract, debtSample);

        // Assert
        //  Verify that debt was set correctly
        DebtEngine.DebtBase memory debt = debtEngine.debt(testContract);
        assertEq(debt.interestRate, 5);
        assertEq(debt.parValue, 1000);
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
        DebtEngine.CreditEvents memory credit = debtEngine.creditEvents(
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

    function testCanReturnCMTATDebt() public {
        // Arrange
        vm.prank(admin);
        debtEngine.setDebt(address(cmtat), debtSample);

        vm.prank(admin);
        cmtat.setDebtEngine(debtEngine);

        // Call from CMTAT, return debt smart contract
        DebtEngine.DebtBase memory debt = cmtat.debt();
        assertEq(debt.parValue, 1000);
    }

    function testCanReturnCMTATCreditEvents() public {
        // Call as admin to set credit events for non-admin's contract
        vm.prank(admin);
        debtEngine.setCreditEvents(address(cmtat), creditEventSample);

        vm.prank(admin);
        cmtat.setDebtEngine(debtEngine);

        // Call from attacker, should return credit events for attacker address
        vm.prank(attacker);
        DebtEngine.CreditEvents memory credit = cmtat.creditEvents();
        assertEq(credit.flagRedeemed, true);
    }

    function testSetDebtsBatchAsAdmin() public {
        // Call as admin to set multiple debts
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = testContract2;

        DebtEngine.DebtBase[] memory debts = new DebtEngine.DebtBase[](2);
        debts[0] = debtSample1;
        debts[1] = debtSample2;

        vm.prank(admin);
        debtEngine.setDebtBatch(contracts, debts);

        // Verify that both debts were set correctly
        DebtEngine.DebtBase memory debt1 = debtEngine.debt(testContract1);
        assertEq(debt1.interestRate, 5);
        assertEq(debt1.parValue, 1000);

        DebtEngine.DebtBase memory debt2 = debtEngine.debt(testContract2);
        assertEq(debt2.interestRate, 6);
        assertEq(debt2.parValue, 2000);
    }

    function testSetDebtsBatchAsNonAdminFails() public {
        // Attempt to set multiple debts as non-admin
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = testContract2;

        DebtEngine.DebtBase[] memory debts = new DebtEngine.DebtBase[](2);
        debts[0] = debtSample1;
        debts[1] = debtSample2;

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

        DebtEngine.CreditEvents[]
            memory creditEventsList = new DebtEngine.CreditEvents[](2);
        creditEventsList[0] = creditEventSample1;
        creditEventsList[1] = creditEventSample2;

        vm.prank(admin);
        debtEngine.setCreditEventsBatch(contracts, creditEventsList);

        // Verify that both credit events were set correctly
        DebtEngine.CreditEvents memory credit1 = debtEngine.creditEvents(
            testContract1
        );
        assertEq(credit1.flagDefault, false);
        assertEq(credit1.rating, "AAA");

        DebtEngine.CreditEvents memory credit2 = debtEngine.creditEvents(
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

        DebtEngine.CreditEvents[]
            memory creditEventsList = new DebtEngine.CreditEvents[](2);
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

    function testSetDebtsBatchLengthMismatch() public {
        // Set arrays with mismatched lengths
        address[] memory contracts = new address[](1);
        contracts[0] = testContract1;

        DebtEngine.DebtBase[] memory debts = new DebtEngine.DebtBase[](2);
        debts[0] = debtSample1;
        debts[1] = debtSample2;

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(InvalidInputLength.selector));
        debtEngine.setDebtBatch(contracts, debts);
    }

    function testSetCreditEventsBatchLengthMismatch() public {
        // Set arrays with mismatched lengths
        address[] memory contracts = new address[](1);
        contracts[0] = testContract1;

        DebtEngine.CreditEvents[]
            memory creditEventsList = new DebtEngine.CreditEvents[](2);
        creditEventsList[0] = creditEventSample1;
        creditEventsList[1] = creditEventSample2;

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(InvalidInputLength.selector));
        debtEngine.setCreditEventsBatch(contracts, creditEventsList);
    }
}
