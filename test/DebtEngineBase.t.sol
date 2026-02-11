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
import {CMTATStandaloneDebt} from "CMTAT/deployment/debt/CMTATStandaloneDebt.sol";
import {ICMTATConstructor} from "CMTAT/interfaces/technical/ICMTATConstructor.sol";

abstract contract DebtEngineBaseTest is Test, DebtEngineInvariantStorage {
    DebtEngine internal debtEngine;
    address internal admin = address(0x1);
    address internal attacker = address(0x2);
    address internal testContract = address(0x3);
    address internal testContract1 = address(0x4);
    address internal testContract2 = address(0x5);
    address internal AddressZero = address(0);
    CMTATStandaloneDebt internal cmtat;

    // Sample data for DebtInformation and CreditEvents
    ICMTATDebt.DebtInformation internal debtSample;

    ICMTATCreditEvents.CreditEvents internal creditEventSample =
        ICMTATCreditEvents.CreditEvents({flagDefault: false, flagRedeemed: true, rating: "AAA"});

    ICMTATDebt.DebtIdentifier internal debtIdentifier1 = ICMTATDebt.DebtIdentifier({
        issuerName: "Name", issuerDescription: "Description", guarantor: "Guarantor A", debtHolder: "Bond Holder B"
    });

    ICMTATDebt.DebtInstrument internal debtSample1 = ICMTATDebt.DebtInstrument({
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

    ICMTATDebt.DebtInstrument internal debtSample2 = ICMTATDebt.DebtInstrument({
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

    ICMTATDebt.DebtIdentifier internal debtIdentifier2 = ICMTATDebt.DebtIdentifier({
        issuerName: "Name2", issuerDescription: "Description2", guarantor: "Guarantor B", debtHolder: "Bond Holder C"
    });

    ICMTATCreditEvents.CreditEvents internal creditEventSample1 =
        ICMTATCreditEvents.CreditEvents({flagDefault: false, flagRedeemed: true, rating: "AAA"});

    ICMTATCreditEvents.CreditEvents internal creditEventSample2 =
        ICMTATCreditEvents.CreditEvents({flagDefault: true, flagRedeemed: false, rating: "BBB"});

    function setUp() public {
        debtSample = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier1, debtInstrument: debtSample1});

        _deployEngine();

        ICMTATConstructor.ERC20Attributes memory erc20Attributes =
            ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", 0);
        ICMTATConstructor.BaseModuleAttributes memory baseModuleAttributes = ICMTATConstructor.BaseModuleAttributes(
            "CMTAT_ISIN", IERC1643CMTAT.DocumentInfo("terms", "https://cmta.ch", bytes32(0)), "CMTAT_info"
        );
        ICMTATConstructor.Engine memory engines =
            ICMTATConstructor.Engine(IRuleEngine(AddressZero), ISnapshotEngine(AddressZero), IERC1643(AddressZero));
        cmtat = new CMTATStandaloneDebt(admin, erc20Attributes, baseModuleAttributes, engines);
    }

    function _deployEngine() internal virtual;
    function _expectUnauthorizedDebtRevert(address caller) internal virtual;
    function _expectUnauthorizedCreditEventsRevert(address caller) internal virtual;

    /*//////////////////////////////////////////////////////////////
            DEPLOYMENT
    ///////////////////////////////////////*/

    function testDeploy() public virtual;

    /*//////////////////////////////////////////////////////////////
              Set/Get Debt
    ///////////////////////////////////////*/

    function testSetDebtAsAdmin() public {
        vm.prank(admin);
        debtEngine.setDebt(testContract, debtSample);

        ICMTATDebt.DebtInformation memory d = debtEngine.debt(testContract);
        assertEq(d.debtInstrument.interestRate, 5);
        assertEq(d.debtInstrument.parValue, 1000);
    }

    function testCanAdminSetCreditEvents() public {
        vm.prank(admin);
        debtEngine.setCreditEvents(testContract, creditEventSample);

        ICMTATCreditEvents.CreditEvents memory credit = debtEngine.creditEvents(testContract);
        assertEq(credit.flagDefault, false);
        assertEq(credit.flagRedeemed, true);
        assertEq(credit.rating, "AAA");
    }

    function testSetDebtsBatchAsAdmin() public {
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = testContract2;

        ICMTATDebt.DebtInformation[] memory debts = new ICMTATDebt.DebtInformation[](2);
        debts[0] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier1, debtInstrument: debtSample1});
        debts[1] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier2, debtInstrument: debtSample2});

        vm.prank(admin);
        debtEngine.setDebtBatch(contracts, debts);

        ICMTATDebt.DebtInformation memory debt1 = debtEngine.debt(testContract1);
        assertEq(debt1.debtInstrument.interestRate, 5);
        assertEq(debt1.debtInstrument.parValue, 1000);

        ICMTATDebt.DebtInformation memory debt2 = debtEngine.debt(testContract2);
        assertEq(debt2.debtInstrument.interestRate, 6);
        assertEq(debt2.debtInstrument.parValue, 2000);
    }

    function testSetCreditEventsBatchAsAdmin() public {
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = testContract2;

        ICMTATCreditEvents.CreditEvents[] memory creditEventsList = new ICMTATCreditEvents.CreditEvents[](2);
        creditEventsList[0] = creditEventSample1;
        creditEventsList[1] = creditEventSample2;

        vm.prank(admin);
        debtEngine.setCreditEventsBatch(contracts, creditEventsList);

        ICMTATCreditEvents.CreditEvents memory credit1 = debtEngine.creditEvents(testContract1);
        assertEq(credit1.flagDefault, false);
        assertEq(credit1.rating, "AAA");

        ICMTATCreditEvents.CreditEvents memory credit2 = debtEngine.creditEvents(testContract2);
        assertEq(credit2.flagDefault, true);
        assertEq(credit2.rating, "BBB");
    }

    /*//////////////////////////////////////////////////////////////
            CMTAT Integration
    ///////////////////////////////////////*/

    function testCanReturnCMTATDebt() public {
        vm.prank(admin);
        debtEngine.setDebt(address(cmtat), debtSample);

        vm.prank(admin);
        cmtat.setDebtEngine(debtEngine);

        ICMTATDebt.DebtInformation memory d = cmtat.debt();
        assertEq(d.debtInstrument.parValue, 1000);
    }

    function testCanReturnCMTATCreditEvents() public {
        vm.prank(admin);
        debtEngine.setCreditEvents(address(cmtat), creditEventSample);

        vm.prank(admin);
        cmtat.setDebtEngine(debtEngine);

        vm.prank(attacker);
        ICMTATCreditEvents.CreditEvents memory credit = cmtat.creditEvents();
        assertEq(credit.flagRedeemed, true);
    }

    /*//////////////////////////////////////////////////////////////
           INVALID PARAMETER
    ///////////////////////////////////////*/

    function testSetDebtsBatchLengthMismatch() public {
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
        address[] memory contracts = new address[](1);
        contracts[0] = testContract1;

        ICMTATCreditEvents.CreditEvents[] memory creditEventsList = new ICMTATCreditEvents.CreditEvents[](2);
        creditEventsList[0] = creditEventSample1;
        creditEventsList[1] = creditEventSample2;

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(InvalidInputLength.selector));
        debtEngine.setCreditEventsBatch(contracts, creditEventsList);
    }

    function testCannotSetDebtForAddressZero() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(SmartContractWithAddressZeroNotAllowed.selector));
        debtEngine.setDebt(AddressZero, debtSample);
    }

    function testCannotSetCreditEventsForAddressZero() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(SmartContractWithAddressZeroNotAllowed.selector));
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
        vm.expectRevert(abi.encodeWithSelector(SmartContractWithAddressZeroNotAllowed.selector));
        debtEngine.setDebtBatch(contracts, debts);
    }

    function testCannotSetCreditEventsBatchWithAddressZero() public {
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = AddressZero;

        ICMTATCreditEvents.CreditEvents[] memory creditEventsList = new ICMTATCreditEvents.CreditEvents[](2);
        creditEventsList[0] = creditEventSample1;
        creditEventsList[1] = creditEventSample2;

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(SmartContractWithAddressZeroNotAllowed.selector));
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

        ICMTATCreditEvents.CreditEvents[] memory creditEventsList = new ICMTATCreditEvents.CreditEvents[](2);
        creditEventsList[0] = creditEventSample1;
        creditEventsList[1] = creditEventSample2;

        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit DebtEngine.CreditEventsSet(testContract1);
        vm.expectEmit(true, false, false, false);
        emit DebtEngine.CreditEventsSet(testContract2);
        debtEngine.setCreditEventsBatch(contracts, creditEventsList);
    }

    /*//////////////////////////////////////////////////////////////
           HAS DEBT / HAS CREDIT EVENTS
    ///////////////////////////////////////*/

    function testHasDebtReturnsFalseWhenNotSet() public view {
        assertEq(debtEngine.hasDebt(testContract), false);
    }

    function testHasDebtReturnsTrueWhenSet() public {
        vm.prank(admin);
        debtEngine.setDebt(testContract, debtSample);

        assertEq(debtEngine.hasDebt(testContract), true);
    }

    function testHasCreditEventsReturnsFalseWhenNotSet() public view {
        assertEq(debtEngine.hasCreditEvents(testContract), false);
    }

    function testHasCreditEventsReturnsTrueWhenSet() public {
        vm.prank(admin);
        debtEngine.setCreditEvents(testContract, creditEventSample);

        assertEq(debtEngine.hasCreditEvents(testContract), true);
    }

    function testHasDebtBatchSetsFlags() public {
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = testContract2;

        ICMTATDebt.DebtInformation[] memory debts = new ICMTATDebt.DebtInformation[](2);
        debts[0] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier1, debtInstrument: debtSample1});
        debts[1] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier2, debtInstrument: debtSample2});

        assertEq(debtEngine.hasDebt(testContract1), false);
        assertEq(debtEngine.hasDebt(testContract2), false);

        vm.prank(admin);
        debtEngine.setDebtBatch(contracts, debts);

        assertEq(debtEngine.hasDebt(testContract1), true);
        assertEq(debtEngine.hasDebt(testContract2), true);
    }

    function testHasCreditEventsBatchSetsFlags() public {
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = testContract2;

        ICMTATCreditEvents.CreditEvents[] memory creditEventsList = new ICMTATCreditEvents.CreditEvents[](2);
        creditEventsList[0] = creditEventSample1;
        creditEventsList[1] = creditEventSample2;

        assertEq(debtEngine.hasCreditEvents(testContract1), false);
        assertEq(debtEngine.hasCreditEvents(testContract2), false);

        vm.prank(admin);
        debtEngine.setCreditEventsBatch(contracts, creditEventsList);

        assertEq(debtEngine.hasCreditEvents(testContract1), true);
        assertEq(debtEngine.hasCreditEvents(testContract2), true);
    }
}
