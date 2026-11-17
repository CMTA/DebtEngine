// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {DebtEngineBase} from "../src/DebtEngineBase.sol";
import {ICMTATDebt, ICMTATCreditEvents} from "CMTAT/interfaces/tokenization/ICMTAT.sol";

/**
 * @dev Test-only engine with no access control and no ERC-2771.
 * It overrides public functions of `DebtEngineBase`, so removing `virtual` from them breaks the build,
 * and it relies on the base `_msgSender()` (`msg.sender`), which both deployment contracts override.
 */
contract DebtEngineHarness is DebtEngineBase {
    bool public overridesReached;

    function setDebt(address smartContract_, DebtInformation calldata debt_) external override {
        overridesReached = true;
        _setDebt(smartContract_, debt_);
    }

    function hasDebt(address) external pure override returns (bool) {
        return true;
    }

    function _authorizeSetDebt() internal view override {}

    function _authorizeSetCreditEvents() internal view override {}
}

contract DebtEngineHarnessTest is Test {
    DebtEngineHarness internal harness;

    function setUp() public {
        harness = new DebtEngineHarness();
    }

    function testOverridesOfPublicFunctionsAreReached() public {
        assertTrue(harness.hasDebt(address(0x1234)));

        ICMTATDebt.DebtInformation memory info;
        info.debtInstrument.parValue = 42;
        harness.setDebt(address(this), info);
        assertTrue(harness.overridesReached());
    }

    function testBaseMsgSenderIsMsgSender() public {
        ICMTATDebt.DebtInformation memory info;
        info.debtInstrument.parValue = 42;
        harness.setDebt(address(this), info);

        // debt() resolves the caller through the base _msgSender(), i.e. msg.sender
        assertEq(harness.debt().debtInstrument.parValue, 42);

        ICMTATCreditEvents.CreditEvents memory c = harness.creditEvents();
        assertEq(c.rating, "");
    }
}
