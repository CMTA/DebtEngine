// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {DebtEngineAccessControl} from "../src/deployment/DebtEngineAccessControl.sol";
import {DebtEngineOwnable} from "../src/deployment/DebtEngineOwnable.sol";
import {IAccessControl} from "OZ/access/IAccessControl.sol";
import {ERC1967Proxy} from "OZ/proxy/ERC1967/ERC1967Proxy.sol";
import {ICMTATDebt, ICMTATCreditEvents} from "CMTAT/interfaces/tokenization/ICMTAT.sol";
import {IDebtEngine} from "CMTAT/interfaces/engine/IDebtEngine.sol";
import {IERC1643CMTAT} from "CMTAT/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {ISnapshotEngine} from "CMTAT/interfaces/engine/ISnapshotEngine.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IERC1643} from "CMTAT/interfaces/tokenization/draft-IERC1643.sol";
import {CMTATStandaloneDebt} from "CMTAT/deployment/debt/CMTATStandaloneDebt.sol";
import {CMTATUpgradeableDebt} from "CMTAT/deployment/debt/CMTATUpgradeableDebt.sol";
import {DebtEngineModule} from "CMTAT/modules/wrapper/options/DebtEngineModule.sol";
import {ICMTATConstructor} from "CMTAT/interfaces/technical/ICMTATConstructor.sol";

/**
 * @dev Runs, step by step, the procedures of
 * doc/technical/guides/DEPLOY_DEBT_ENGINE_CMTAT_V3.0.0.md against CMTAT v3.0.0.
 * Each test name maps to a section of the guide.
 */
contract DeployGuideCMTATv300Test is Test {
    address internal admin = address(0xA11CE); // engine admin / owner
    address internal tokenAdmin = address(0x70AD); // CMTAT DEFAULT_ADMIN_ROLE (implicitly DEBT_ROLE)
    address internal debtManager = address(0xDEB7);
    address internal creditManager = address(0xC2ED);
    address internal multisig = address(0x5AFE);

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/

    function _attrs()
        internal
        pure
        returns (
            ICMTATConstructor.ERC20Attributes memory erc20,
            ICMTATConstructor.ExtraInformationAttributes memory extra,
            ICMTATConstructor.Engine memory engines
        )
    {
        erc20 = ICMTATConstructor.ERC20Attributes("Bond 2030", "BND30", 0);
        extra = ICMTATConstructor.ExtraInformationAttributes(
            "CH0000000000", IERC1643CMTAT.DocumentInfo("terms", "https://example.com/terms", bytes32(0)), "Bond"
        );
        engines = ICMTATConstructor.Engine(IRuleEngine(address(0)), ISnapshotEngine(address(0)), IERC1643(address(0)));
    }

    function _deployStandaloneToken() internal returns (CMTATStandaloneDebt token) {
        (
            ICMTATConstructor.ERC20Attributes memory erc20,
            ICMTATConstructor.ExtraInformationAttributes memory extra,
            ICMTATConstructor.Engine memory engines
        ) = _attrs();
        token = new CMTATStandaloneDebt(tokenAdmin, erc20, extra, engines);
    }

    function _debt(uint256 parValue, string memory issuer) internal pure returns (ICMTATDebt.DebtInformation memory d) {
        d.debtIdentifier.issuerName = issuer;
        d.debtInstrument.parValue = parValue;
        d.debtInstrument.interestRate = 5;
        d.debtInstrument.currency = "CHF";
    }

    function _credit(string memory rating) internal pure returns (ICMTATCreditEvents.CreditEvents memory c) {
        c = ICMTATCreditEvents.CreditEvents({flagDefault: false, flagRedeemed: false, rating: rating});
    }

    /*//////////////////////////////////////////////////////////////
          §4.1 — DebtEngineAccessControl + CMTATStandaloneDebt
    //////////////////////////////////////////////////////////////*/

    function testGuide_4_1_AccessControlWithStandaloneToken() public {
        // Step 1 — deploy the engine (no forwarder)
        DebtEngineAccessControl engine = new DebtEngineAccessControl(admin, address(0));
        assertEq(engine.version(), "0.3.0");

        // Step 2 — grant the operational roles
        vm.startPrank(admin);
        engine.grantRole(engine.DEBT_MANAGER_ROLE(), debtManager);
        engine.grantRole(engine.CREDIT_EVENTS_MANAGER_ROLE(), creditManager);
        vm.stopPrank();

        // Step 3 — deploy the token
        CMTATStandaloneDebt token = _deployStandaloneToken();

        // Step 4 — write the token's records in the engine BEFORE connecting it
        vm.prank(debtManager);
        engine.setDebt(address(token), _debt(1000, "Issuer SA"));
        vm.prank(creditManager);
        engine.setCreditEvents(address(token), _credit("AAA"));

        // Step 5 — connect the token to the engine (token side, DEBT_ROLE)
        vm.expectEmit(true, false, false, false, address(token));
        emit DebtEngineModule.DebtEngine(IDebtEngine(address(engine)));
        vm.prank(tokenAdmin);
        token.setDebtEngine(engine);

        // Step 6 — verify
        assertEq(address(token.debtEngine()), address(engine));
        assertTrue(engine.hasDebt(address(token)));
        assertTrue(engine.hasCreditEvents(address(token)));
        assertEq(token.debt().debtInstrument.parValue, 1000);
        assertEq(token.debt().debtIdentifier.issuerName, "Issuer SA");
        assertEq(token.creditEvents().rating, "AAA");
    }

    /*//////////////////////////////////////////////////////////////
          §4.2 — DebtEngineOwnable + handover to a multisig
    //////////////////////////////////////////////////////////////*/

    function testGuide_4_2_OwnableWithStandaloneToken() public {
        // Step 1 — deploy, owner = deployer key
        DebtEngineOwnable engine = new DebtEngineOwnable(admin, address(0));

        // Step 2 — deploy the token and write its records
        CMTATStandaloneDebt token = _deployStandaloneToken();
        vm.startPrank(admin);
        engine.setDebt(address(token), _debt(500, "Issuer SA"));
        engine.setCreditEvents(address(token), _credit("BBB"));

        // Step 3 — two-step handover to the multisig
        engine.transferOwnership(multisig);
        vm.stopPrank();
        assertEq(engine.owner(), admin, "nothing moves before acceptance");
        vm.prank(multisig);
        engine.acceptOwnership();
        assertEq(engine.owner(), multisig);

        // Step 4 — connect and verify
        vm.prank(tokenAdmin);
        token.setDebtEngine(engine);
        assertEq(token.debt().debtInstrument.parValue, 500);
        assertEq(token.creditEvents().rating, "BBB");
    }

    /*//////////////////////////////////////////////////////////////
          §4.3 — Upgradeable token behind an ERC-1967 proxy
    //////////////////////////////////////////////////////////////*/

    function testGuide_4_3_UpgradeableTokenThroughProxy() public {
        DebtEngineAccessControl engine = new DebtEngineAccessControl(admin, address(0));

        (
            ICMTATConstructor.ERC20Attributes memory erc20,
            ICMTATConstructor.ExtraInformationAttributes memory extra,
            ICMTATConstructor.Engine memory engines
        ) = _attrs();
        CMTATUpgradeableDebt implementation = new CMTATUpgradeableDebt();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSignature(
                // initialize is overloaded across CMTAT bases: name the debt variant's signature explicitly
                "initialize(address,(string,string,uint8),(string,(string,string,bytes32),string),(address,address,address))",
                tokenAdmin,
                erc20,
                extra,
                engines
            )
        );
        CMTATUpgradeableDebt token = CMTATUpgradeableDebt(address(proxy));

        // The record is keyed by the PROXY address, the one holders and integrators call
        vm.prank(admin);
        engine.setDebt(address(proxy), _debt(2000, "Issuer SA"));
        vm.prank(tokenAdmin);
        token.setDebtEngine(engine);

        assertEq(token.debt().debtInstrument.parValue, 2000);
        assertFalse(engine.hasDebt(address(implementation)), "nothing stored for the implementation");
    }

    /*//////////////////////////////////////////////////////////////
          §5 — One engine, several tokens
    //////////////////////////////////////////////////////////////*/

    function testGuide_5_OneEngineSeveralTokens() public {
        DebtEngineAccessControl engine = new DebtEngineAccessControl(admin, address(0));
        CMTATStandaloneDebt tokenA = _deployStandaloneToken();
        CMTATStandaloneDebt tokenB = _deployStandaloneToken();

        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        ICMTATDebt.DebtInformation[] memory debts = new ICMTATDebt.DebtInformation[](2);
        debts[0] = _debt(100, "Issuer A");
        debts[1] = _debt(200, "Issuer B");

        vm.prank(admin);
        engine.setDebtBatch(tokens, debts);

        vm.startPrank(tokenAdmin);
        tokenA.setDebtEngine(engine);
        tokenB.setDebtEngine(engine);
        vm.stopPrank();

        assertEq(tokenA.debt().debtInstrument.parValue, 100);
        assertEq(tokenB.debt().debtInstrument.parValue, 200);
    }

    /*//////////////////////////////////////////////////////////////
          §6 — Order matters: connecting first hides the token's own data
    //////////////////////////////////////////////////////////////*/

    function testGuide_6_ConnectingBeforeWritingHidesLocalData() public {
        DebtEngineAccessControl engine = new DebtEngineAccessControl(admin, address(0));
        CMTATStandaloneDebt token = _deployStandaloneToken();

        vm.startPrank(tokenAdmin);
        token.setDebt(_debt(1000, "Local"));
        assertEq(token.debt().debtInstrument.parValue, 1000);
        token.setDebtEngine(engine); // engine has no record yet
        vm.stopPrank();

        assertEq(token.debt().debtInstrument.parValue, 0, "token now reads the engine's empty record");
        assertFalse(engine.hasDebt(address(token)));
    }

    /*//////////////////////////////////////////////////////////////
          §7 — Operating: update, clear, disconnect, replace
    //////////////////////////////////////////////////////////////*/

    function testGuide_7_Operations() public {
        DebtEngineAccessControl engine = new DebtEngineAccessControl(admin, address(0));
        CMTATStandaloneDebt token = _deployStandaloneToken();

        vm.prank(tokenAdmin);
        token.setDebt(_debt(1, "Local"));

        vm.prank(admin);
        engine.setDebt(address(token), _debt(1000, "Issuer SA"));
        vm.prank(tokenAdmin);
        token.setDebtEngine(engine);

        // Update a record: the token sees it immediately
        vm.prank(admin);
        engine.setDebt(address(token), _debt(1100, "Issuer SA"));
        assertEq(token.debt().debtInstrument.parValue, 1100);

        // Record a credit event (e.g. default)
        vm.prank(admin);
        engine.setCreditEvents(
            address(token), ICMTATCreditEvents.CreditEvents({flagDefault: true, flagRedeemed: false, rating: "D"})
        );
        assertTrue(token.creditEvents().flagDefault);

        // Clear a record: the token reports an empty record, hasDebt is false
        vm.prank(admin);
        engine.clearDebt(address(token));
        assertEq(token.debt().debtInstrument.parValue, 0);
        assertFalse(engine.hasDebt(address(token)));

        // Setting the same engine again reverts on the token side
        vm.expectRevert(DebtEngineModule.CMTAT_DebtEngineModule_SameValue.selector);
        vm.prank(tokenAdmin);
        token.setDebtEngine(engine);

        // Replace the engine with a new one
        DebtEngineAccessControl engine2 = new DebtEngineAccessControl(admin, address(0));
        vm.prank(admin);
        engine2.setDebt(address(token), _debt(3000, "Issuer SA"));
        vm.prank(tokenAdmin);
        token.setDebtEngine(engine2);
        assertEq(token.debt().debtInstrument.parValue, 3000);

        // Disconnect: the token falls back to its own DebtModule data
        vm.prank(tokenAdmin);
        token.setDebtEngine(IDebtEngine(address(0)));
        assertEq(token.debt().debtInstrument.parValue, 1);
    }

    /*//////////////////////////////////////////////////////////////
          §7 — Roles: who can do what
    //////////////////////////////////////////////////////////////*/

    function testGuide_7_RolesAreSeparated() public {
        DebtEngineAccessControl engine = new DebtEngineAccessControl(admin, address(0));
        CMTATStandaloneDebt token = _deployStandaloneToken();
        bytes32 debtManagerRole = engine.DEBT_MANAGER_ROLE();
        bytes32 creditManagerRole = engine.CREDIT_EVENTS_MANAGER_ROLE();

        vm.startPrank(admin);
        engine.grantRole(debtManagerRole, debtManager);
        engine.grantRole(creditManagerRole, creditManager);
        vm.stopPrank();

        // The credit-events manager cannot write debt
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, creditManager, debtManagerRole
            )
        );
        vm.prank(creditManager);
        engine.setDebt(address(token), _debt(1, "x"));

        // An engine manager cannot connect the token: that is the token's DEBT_ROLE
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, debtManager, token.DEBT_ROLE()
            )
        );
        vm.prank(debtManager);
        token.setDebtEngine(engine);
    }

    /*//////////////////////////////////////////////////////////////
          §8 — Admin handover runbook (RBAC)
    //////////////////////////////////////////////////////////////*/

    function testGuide_8_AdminHandoverRunbook() public {
        DebtEngineAccessControl engine = new DebtEngineAccessControl(admin, address(0));
        bytes32 debtManagerRole = engine.DEBT_MANAGER_ROLE();

        // 1. grant admin to the multisig, 2. renounce, 3. the multisig grants the manager role
        vm.startPrank(admin);
        engine.grantRole(engine.DEFAULT_ADMIN_ROLE(), multisig);
        engine.renounceRole(engine.DEFAULT_ADMIN_ROLE(), admin);
        vm.stopPrank();
        vm.prank(multisig);
        engine.grantRole(debtManagerRole, admin);

        assertFalse(engine.hasRole(engine.DEFAULT_ADMIN_ROLE(), admin));
        assertEq(engine.getRoleMember(debtManagerRole, 0), admin);
        vm.prank(admin);
        engine.setDebt(address(0x1234), _debt(1, "x"));
    }
}
