// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/DebtEngine.sol";
import "CMTAT/interfaces/engine/IDebtEngine.sol";
import {IDebtGlobal} from "CMTAT/interfaces/IDebtGlobal.sol";
import "../src/DebtEngineInvariantStorage.sol";
import "OZ/access/AccessControl.sol";
import "CMTAT/CMTAT_STANDALONE.sol";
contract DebtEngineTest is Test, AccessControl, IDebtGlobal, DebtEngineInvariantStorage {
    DebtEngine private debtEngine;
    address private admin = address(0x1);
    address private attacker = address(0x2);
    address private testContract = address(0x3);
    address AddressZero = address(0);
    CMTAT_STANDALONE cmtat;

    // Sample data for DebtBase and CreditEvents
    DebtEngine.DebtBase private debtSample = DebtBase({
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

    DebtEngine.CreditEvents private creditEventSample = CreditEvents({
        flagDefault: false,
        flagRedeemed: true,
        rating: "AAA"
    });

    function setUp() public {
        // Deploy the DebtEngine contract with admin role
        debtEngine = new DebtEngine(admin);
        ICMTATConstructor.ERC20Attributes memory erc20Attributes = ICMTATConstructor.ERC20Attributes('CMTA Token', 'CMTAT', 0);
        ICMTATConstructor.BaseModuleAttributes memory baseModuleAttributes = ICMTATConstructor.BaseModuleAttributes('CMTAT_ISIN',  'https://cmta.ch', 'CMTAT_info');
        ICMTATConstructor.Engine memory engines =  ICMTATConstructor.Engine(IRuleEngine(AddressZero), IDebtEngine(AddressZero), IAuthorizationEngine(AddressZero), IERC1643(AddressZero));
        cmtat = new CMTAT_STANDALONE(AddressZero, admin, erc20Attributes,  baseModuleAttributes, engines);
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
                DEBT_ROLE
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
        DebtEngine.CreditEvents memory credit = debtEngine.creditEvents(testContract);
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
                CREDIT_EVENTS_ROLE
            )
        );
        debtEngine.setCreditEvents(testContract, creditEventSample) ;
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
}