// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {DebtEngineBase} from "../src/DebtEngineBase.sol";
import {ICMTATDebt, ICMTATCreditEvents} from "CMTAT/interfaces/tokenization/ICMTAT.sol";
import {IERC1643CMTAT} from "CMTAT/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {ISnapshotEngine} from "CMTAT/interfaces/engine/ISnapshotEngine.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IERC1643} from "CMTAT/interfaces/tokenization/draft-IERC1643.sol";
import {DebtEngineInvariantStorage} from "../src/DebtEngineInvariantStorage.sol";
import {CMTATStandaloneDebt} from "CMTAT/deployment/debt/CMTATStandaloneDebt.sol";
import {ICMTATConstructor} from "CMTAT/interfaces/technical/ICMTATConstructor.sol";

abstract contract DebtEngineBaseTest is Test, DebtEngineInvariantStorage {
    DebtEngineBase internal debtEngine;
    address internal admin = address(0x1);
    address internal attacker = address(0x2);
    address internal testContract = address(0x3);
    address internal testContract1 = address(0x4);
    address internal testContract2 = address(0x5);
    address internal constant ADDRESS_ZERO = address(0);
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
        ICMTATConstructor.ExtraInformationAttributes memory extraInformationAttributes =
            ICMTATConstructor.ExtraInformationAttributes(
                "CMTAT_ISIN", IERC1643CMTAT.DocumentInfo("terms", "https://cmta.ch", bytes32(0)), "CMTAT_info"
            );
        ICMTATConstructor.Engine memory engines =
            ICMTATConstructor.Engine(IRuleEngine(ADDRESS_ZERO), ISnapshotEngine(ADDRESS_ZERO), IERC1643(ADDRESS_ZERO));
        cmtat = new CMTATStandaloneDebt(admin, erc20Attributes, extraInformationAttributes, engines);
    }

    function _deployEngine() internal virtual;
    function _deployEngineWithForwarder(address forwarder) internal virtual returns (DebtEngineBase);
    function _expectUnauthorizedDebtRevert(address caller) internal virtual;
    function _expectUnauthorizedCreditEventsRevert(address caller) internal virtual;

    /*//////////////////////////////////////////////////////////////
            DEPLOYMENT
    ///////////////////////////////////////*/

    function testDeploy() public virtual;

    function testVersion() public view {
        assertEq(debtEngine.version(), "0.3.0");
    }

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

    // More addresses than records: must revert with InvalidInputLength, not an out-of-bounds panic
    function testSetDebtsBatchMoreAddressesThanRecords() public {
        ICMTATDebt.DebtInformation[] memory debts = new ICMTATDebt.DebtInformation[](1);
        debts[0] = debtSample;

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(InvalidInputLength.selector));
        debtEngine.setDebtBatch(_addresses(2), debts);
    }

    function testSetCreditEventsBatchMoreAddressesThanRecords() public {
        ICMTATCreditEvents.CreditEvents[] memory creditEventsList = new ICMTATCreditEvents.CreditEvents[](1);
        creditEventsList[0] = creditEventSample1;

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(InvalidInputLength.selector));
        debtEngine.setCreditEventsBatch(_addresses(2), creditEventsList);
    }

    function testCannotSetDebtForAddressZero() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(SmartContractWithAddressZeroNotAllowed.selector));
        debtEngine.setDebt(ADDRESS_ZERO, debtSample);
    }

    function testCannotSetCreditEventsForAddressZero() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(SmartContractWithAddressZeroNotAllowed.selector));
        debtEngine.setCreditEvents(ADDRESS_ZERO, creditEventSample);
    }

    function testCannotSetDebtBatchWithAddressZero() public {
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = ADDRESS_ZERO;

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
        contracts[1] = ADDRESS_ZERO;

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
        emit DebtEngineBase.DebtSet(testContract);
        debtEngine.setDebt(testContract, debtSample);
    }

    function testSetCreditEventsEmitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit DebtEngineBase.CreditEventsSet(testContract);
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
        emit DebtEngineBase.DebtSet(testContract1);
        vm.expectEmit(true, false, false, false);
        emit DebtEngineBase.DebtSet(testContract2);
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
        emit DebtEngineBase.CreditEventsSet(testContract1);
        vm.expectEmit(true, false, false, false);
        emit DebtEngineBase.CreditEventsSet(testContract2);
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

    /*//////////////////////////////////////////////////////////////
              Batch size limit
    ///////////////////////////////////////*/

    function _addresses(uint256 n) internal pure returns (address[] memory list) {
        list = new address[](n);
        for (uint256 i = 0; i < n; ++i) {
            list[i] = address(uint160(0x1000 + i));
        }
    }

    function testCannotSetDebtBatchAboveMaxSize() public {
        uint256 n = debtEngine.MAX_BATCH_SIZE() + 1;
        ICMTATDebt.DebtInformation[] memory debts = new ICMTATDebt.DebtInformation[](n);
        vm.expectRevert(abi.encodeWithSelector(BatchSizeTooLarge.selector, n, n - 1));
        vm.prank(admin);
        debtEngine.setDebtBatch(_addresses(n), debts);
    }

    function testCannotSetCreditEventsBatchAboveMaxSize() public {
        uint256 n = debtEngine.MAX_BATCH_SIZE() + 1;
        ICMTATCreditEvents.CreditEvents[] memory list = new ICMTATCreditEvents.CreditEvents[](n);
        vm.expectRevert(abi.encodeWithSelector(BatchSizeTooLarge.selector, n, n - 1));
        vm.prank(admin);
        debtEngine.setCreditEventsBatch(_addresses(n), list);
    }

    function testSetCreditEventsBatchAtMaxSize() public {
        uint256 n = debtEngine.MAX_BATCH_SIZE();
        address[] memory contracts = _addresses(n);
        ICMTATCreditEvents.CreditEvents[] memory list = new ICMTATCreditEvents.CreditEvents[](n);
        for (uint256 i = 0; i < n; ++i) {
            list[i] = creditEventSample1;
        }
        vm.prank(admin);
        debtEngine.setCreditEventsBatch(contracts, list);
        assertTrue(debtEngine.hasCreditEvents(contracts[0]));
        assertTrue(debtEngine.hasCreditEvents(contracts[n - 1]));
    }

    function testSetDebtBatchAtMaxSize() public {
        uint256 n = debtEngine.MAX_BATCH_SIZE();
        address[] memory contracts = _addresses(n);
        ICMTATDebt.DebtInformation[] memory debts = new ICMTATDebt.DebtInformation[](n);
        vm.prank(admin);
        debtEngine.setDebtBatch(contracts, debts);
        assertTrue(debtEngine.hasDebt(contracts[0]));
        assertTrue(debtEngine.hasDebt(contracts[n - 1]));
    }

    /*//////////////////////////////////////////////////////////////
              Batch edge cases
    ///////////////////////////////////////*/

    function testEmptyBatchesAreNoOps() public {
        vm.recordLogs();
        vm.startPrank(admin);
        debtEngine.setDebtBatch(new address[](0), new ICMTATDebt.DebtInformation[](0));
        debtEngine.setCreditEventsBatch(new address[](0), new ICMTATCreditEvents.CreditEvents[](0));
        vm.stopPrank();
        assertEq(vm.getRecordedLogs().length, 0);
    }

    function testDuplicateAddressInDebtBatchLastWriteWins() public {
        address[] memory contracts = new address[](2);
        contracts[0] = testContract1;
        contracts[1] = testContract1;
        ICMTATDebt.DebtInformation[] memory debts = new ICMTATDebt.DebtInformation[](2);
        debts[0] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier1, debtInstrument: debtSample1});
        debts[1] = ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier2, debtInstrument: debtSample2});

        vm.recordLogs();
        vm.prank(admin);
        debtEngine.setDebtBatch(contracts, debts);

        assertEq(vm.getRecordedLogs().length, 2);
        assertEq(debtEngine.debt(testContract1).debtInstrument.interestRate, debtSample2.interestRate);
    }

    function testSetDebtOverwritesPreviousRecord() public {
        vm.startPrank(admin);
        debtEngine.setDebt(testContract, debtSample);
        debtEngine.setDebt(
            testContract, ICMTATDebt.DebtInformation({debtIdentifier: debtIdentifier2, debtInstrument: debtSample2})
        );
        vm.stopPrank();
        ICMTATDebt.DebtInformation memory d = debtEngine.debt(testContract);
        assertEq(d.debtInstrument.interestRate, debtSample2.interestRate);
        assertEq(d.debtIdentifier.issuerName, debtIdentifier2.issuerName);
    }

    /*//////////////////////////////////////////////////////////////
              Fuzz: what is written is what is read
    ///////////////////////////////////////*/

    function testFuzz_SetDebtRoundTrip(
        address target,
        uint256 interestRate,
        uint256 parValue,
        string calldata issuerName
    ) public {
        vm.assume(target != address(0));
        ICMTATDebt.DebtInformation memory info = debtSample;
        info.debtInstrument.interestRate = interestRate;
        info.debtInstrument.parValue = parValue;
        info.debtIdentifier.issuerName = issuerName;

        vm.prank(admin);
        debtEngine.setDebt(target, info);

        ICMTATDebt.DebtInformation memory d = debtEngine.debt(target);
        assertEq(d.debtInstrument.interestRate, interestRate);
        assertEq(d.debtInstrument.parValue, parValue);
        assertEq(d.debtIdentifier.issuerName, issuerName);
        assertTrue(debtEngine.hasDebt(target));
    }

    function testFuzz_SetCreditEventsRoundTrip(
        address target,
        bool flagDefault,
        bool flagRedeemed,
        string calldata rating
    ) public {
        vm.assume(target != address(0));
        vm.prank(admin);
        debtEngine.setCreditEvents(
            target,
            ICMTATCreditEvents.CreditEvents({flagDefault: flagDefault, flagRedeemed: flagRedeemed, rating: rating})
        );

        ICMTATCreditEvents.CreditEvents memory c = debtEngine.creditEvents(target);
        assertEq(c.flagDefault, flagDefault);
        assertEq(c.flagRedeemed, flagRedeemed);
        assertEq(c.rating, rating);
        assertTrue(debtEngine.hasCreditEvents(target));
    }

    /*//////////////////////////////////////////////////////////////
              ERC-2771: trusted forwarder
    ///////////////////////////////////////*/

    address internal constant FORWARDER = address(0xF0);

    function testSetDebtThroughTrustedForwarder() public {
        DebtEngineBase engine = _deployEngineWithForwarder(FORWARDER);
        bytes memory data = abi.encodeCall(DebtEngineBase.setDebt, (testContract, debtSample));

        // The forwarder appends the signer: the authorized signer passes
        vm.prank(FORWARDER);
        (bool ok,) = address(engine).call(abi.encodePacked(data, admin));
        assertTrue(ok);
        assertEq(engine.debt(testContract).debtInstrument.parValue, debtSample.debtInstrument.parValue);
    }

    function testForwarderCannotRelayUnauthorizedSigner() public {
        DebtEngineBase engine = _deployEngineWithForwarder(FORWARDER);
        bytes memory data = abi.encodeCall(DebtEngineBase.setDebt, (testContract, debtSample));

        _expectUnauthorizedDebtRevert(attacker);
        vm.prank(FORWARDER);
        (bool ok,) = address(engine).call(abi.encodePacked(data, attacker));
        assertTrue(ok, "expectRevert: call returns true when the expected revert happened");
    }

    function testUntrustedCallerCannotSpoofSender() public {
        DebtEngineBase engine = _deployEngineWithForwarder(FORWARDER);
        bytes memory data = abi.encodeCall(DebtEngineBase.setDebt, (testContract, debtSample));

        // Appending the admin address from a non-forwarder is ignored: the caller itself is checked
        _expectUnauthorizedDebtRevert(attacker);
        vm.prank(attacker);
        (bool ok,) = address(engine).call(abi.encodePacked(data, admin));
        assertTrue(ok, "expectRevert: call returns true when the expected revert happened");
    }

    function testDebtForCallerThroughTrustedForwarder() public {
        DebtEngineBase engine = _deployEngineWithForwarder(FORWARDER);
        vm.prank(admin);
        engine.setDebt(testContract, debtSample);

        vm.prank(FORWARDER);
        (bool ok, bytes memory ret) =
            address(engine).staticcall(abi.encodePacked(abi.encodeWithSignature("debt()"), testContract));
        assertTrue(ok);
        ICMTATDebt.DebtInformation memory d = abi.decode(ret, (ICMTATDebt.DebtInformation));
        assertEq(d.debtInstrument.parValue, debtSample.debtInstrument.parValue);
    }

    /*//////////////////////////////////////////////////////////////
              Clear
    ///////////////////////////////////////*/

    event DebtCleared(address indexed smartContract);
    event CreditEventsCleared(address indexed smartContract);

    function testClearDebt() public {
        vm.prank(admin);
        debtEngine.setDebt(testContract, debtSample);
        assertTrue(debtEngine.hasDebt(testContract));

        vm.expectEmit(true, false, false, false, address(debtEngine));
        emit DebtCleared(testContract);
        vm.prank(admin);
        debtEngine.clearDebt(testContract);

        assertFalse(debtEngine.hasDebt(testContract));
        ICMTATDebt.DebtInformation memory empty;
        assertEq(abi.encode(debtEngine.debt(testContract)), abi.encode(empty));
    }

    function testClearCreditEvents() public {
        vm.prank(admin);
        debtEngine.setCreditEvents(testContract, creditEventSample);
        assertTrue(debtEngine.hasCreditEvents(testContract));

        vm.expectEmit(true, false, false, false, address(debtEngine));
        emit CreditEventsCleared(testContract);
        vm.prank(admin);
        debtEngine.clearCreditEvents(testContract);

        assertFalse(debtEngine.hasCreditEvents(testContract));
        ICMTATCreditEvents.CreditEvents memory empty;
        assertEq(abi.encode(debtEngine.creditEvents(testContract)), abi.encode(empty));
    }

    function testClearDebtLeavesCreditEventsAndOtherContracts() public {
        vm.startPrank(admin);
        debtEngine.setDebt(testContract, debtSample);
        debtEngine.setDebt(testContract1, debtSample);
        debtEngine.setCreditEvents(testContract, creditEventSample);
        debtEngine.clearDebt(testContract);
        vm.stopPrank();

        assertFalse(debtEngine.hasDebt(testContract));
        assertTrue(debtEngine.hasDebt(testContract1));
        assertTrue(debtEngine.hasCreditEvents(testContract));
        assertEq(debtEngine.creditEvents(testContract).rating, creditEventSample.rating);
    }

    function testClearCreditEventsLeavesDebt() public {
        vm.startPrank(admin);
        debtEngine.setDebt(testContract, debtSample);
        debtEngine.setCreditEvents(testContract, creditEventSample);
        debtEngine.clearCreditEvents(testContract);
        vm.stopPrank();

        assertFalse(debtEngine.hasCreditEvents(testContract));
        assertTrue(debtEngine.hasDebt(testContract));
    }

    function testClearUnsetRecordSucceeds() public {
        vm.expectEmit(true, false, false, false, address(debtEngine));
        emit DebtCleared(testContract);
        vm.prank(admin);
        debtEngine.clearDebt(testContract);
        assertFalse(debtEngine.hasDebt(testContract));

        vm.expectEmit(true, false, false, false, address(debtEngine));
        emit CreditEventsCleared(testContract);
        vm.prank(admin);
        debtEngine.clearCreditEvents(testContract);
        assertFalse(debtEngine.hasCreditEvents(testContract));
    }

    function testSetAfterClear() public {
        vm.startPrank(admin);
        debtEngine.setDebt(testContract, debtSample);
        debtEngine.clearDebt(testContract);
        debtEngine.setDebt(testContract, debtSample);
        vm.stopPrank();

        assertTrue(debtEngine.hasDebt(testContract));
        assertEq(debtEngine.debt(testContract).debtInstrument.parValue, debtSample.debtInstrument.parValue);
    }

    function testCannotUnauthorizedClearDebt() public {
        vm.prank(admin);
        debtEngine.setDebt(testContract, debtSample);

        _expectUnauthorizedDebtRevert(attacker);
        vm.prank(attacker);
        debtEngine.clearDebt(testContract);
        assertTrue(debtEngine.hasDebt(testContract));
    }

    function testCannotUnauthorizedClearCreditEvents() public {
        vm.prank(admin);
        debtEngine.setCreditEvents(testContract, creditEventSample);

        _expectUnauthorizedCreditEventsRevert(attacker);
        vm.prank(attacker);
        debtEngine.clearCreditEvents(testContract);
        assertTrue(debtEngine.hasCreditEvents(testContract));
    }

    function testCMTATReadsEmptyRecordAfterClear() public {
        vm.startPrank(admin);
        debtEngine.setDebt(address(cmtat), debtSample);
        debtEngine.setCreditEvents(address(cmtat), creditEventSample);
        cmtat.setDebtEngine(debtEngine);
        debtEngine.clearDebt(address(cmtat));
        debtEngine.clearCreditEvents(address(cmtat));
        vm.stopPrank();

        assertEq(cmtat.debt().debtInstrument.parValue, 0);
        assertEq(cmtat.creditEvents().rating, "");
    }
}
