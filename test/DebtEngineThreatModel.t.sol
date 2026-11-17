// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Test, Vm} from "forge-std/Test.sol";
import {DebtEngineBase} from "../src/DebtEngineBase.sol";
import {DebtEngineInvariantStorage} from "../src/DebtEngineInvariantStorage.sol";
import {DebtEngineAccessControl} from "../src/deployment/DebtEngineAccessControl.sol";
import {DebtEngineOwnable} from "../src/deployment/DebtEngineOwnable.sol";
import {IAccessControl} from "OZ/access/IAccessControl.sol";
import {Ownable} from "OZ/access/Ownable.sol";
import {ICMTATDebt, ICMTATCreditEvents} from "CMTAT/interfaces/tokenization/ICMTAT.sol";
import {IERC1643CMTAT} from "CMTAT/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {ISnapshotEngine} from "CMTAT/interfaces/engine/ISnapshotEngine.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IERC1643} from "CMTAT/interfaces/tokenization/draft-IERC1643.sol";
import {CMTATStandaloneDebt} from "CMTAT/deployment/debt/CMTATStandaloneDebt.sol";
import {ICMTATConstructor} from "CMTAT/interfaces/technical/ICMTATConstructor.sol";

/**
 * @dev Tests derived from the v0.3.0 security audit, doc/tools/v0.3.0/CLAUDE_AUDIT.md
 * (each test's notice names its finding ID F-n or threat ID). PoC tests assert the current behaviour of a finding;
 * the F-4 PoC was inverted into a regression test once the fix landed.
 */
contract DebtEngineThreatModelTest is Test, DebtEngineInvariantStorage {
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event DebtCleared(address indexed smartContract);
    event CreditEventsCleared(address indexed smartContract);

    address internal admin = address(0xA11CE);
    address internal newAdmin = address(0xB0B);
    address internal forwarder = address(0xF0F0);
    address internal token = address(0x7070);

    DebtEngineAccessControl internal rbac;
    DebtEngineOwnable internal owned;

    bytes32 internal DEBT_MANAGER_ROLE;
    bytes32 internal CREDIT_EVENTS_MANAGER_ROLE;
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    function setUp() public {
        rbac = new DebtEngineAccessControl(admin, forwarder);
        owned = new DebtEngineOwnable(admin, forwarder);
        DEBT_MANAGER_ROLE = rbac.DEBT_MANAGER_ROLE();
        CREDIT_EVENTS_MANAGER_ROLE = rbac.CREDIT_EVENTS_MANAGER_ROLE();
    }

    function _info(uint256 parValue) internal pure returns (ICMTATDebt.DebtInformation memory info) {
        info.debtInstrument.parValue = parValue;
        info.debtIdentifier.issuerName = "Issuer";
    }

    function _credit() internal pure returns (ICMTATCreditEvents.CreditEvents memory c) {
        c = ICMTATCreditEvents.CreditEvents({flagDefault: false, flagRedeemed: true, rating: "AAA"});
    }

    /*//////////////////////////////////////////////////////////////
              AC-3 — implicit-admin hasRole vs role bookkeeping (F-1)
    //////////////////////////////////////////////////////////////*/

    /// @notice AC-3 / F-1 PoC: granting a manager role to an admin records nothing and emits nothing.
    function testPoC_F1_GrantRoleToAdminIsSilentNoOp() public {
        vm.recordLogs();
        vm.prank(admin);
        rbac.grantRole(DEBT_MANAGER_ROLE, admin);

        assertEq(vm.getRecordedLogs().length, 0, "no RoleGranted event");
        assertEq(rbac.getRoleMemberCount(DEBT_MANAGER_ROLE), 0, "admin not enumerated");
        assertTrue(rbac.hasRole(DEBT_MANAGER_ROLE, admin), "yet hasRole reports true");
    }

    /// @notice AC-3 / F-1 PoC: revoking a manager role from an admin emits RoleRevoked, but the admin keeps the power.
    function testPoC_F1_RevokeRoleFromAdminEmitsButKeepsPower() public {
        vm.expectEmit(true, true, true, false, address(rbac));
        emit RoleRevoked(DEBT_MANAGER_ROLE, admin, admin);
        vm.prank(admin);
        rbac.revokeRole(DEBT_MANAGER_ROLE, admin);

        assertTrue(rbac.hasRole(DEBT_MANAGER_ROLE, admin));
        vm.prank(admin);
        rbac.setDebt(token, _info(1));
        assertTrue(rbac.hasDebt(token), "admin still writes after its role was 'revoked'");
    }

    /// @notice AC-3 / F-1 PoC: an admin that "grants" itself a manager role, hands admin over and renounces,
    /// loses the manager role it believed it had kept.
    function testPoC_F1_AdminHandoverDropsSelfGrantedRole() public {
        vm.startPrank(admin);
        rbac.grantRole(DEBT_MANAGER_ROLE, admin); // silent no-op (see above)
        rbac.grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        rbac.renounceRole(DEFAULT_ADMIN_ROLE, admin);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, admin, DEBT_MANAGER_ROLE)
        );
        vm.prank(admin);
        rbac.setDebt(token, _info(1));
    }

    /// @notice AC-3 / F-1 runbook: grant the manager role only after the account stops being admin.
    function testF1_RunbookGrantAfterRenounceWorks() public {
        vm.startPrank(admin);
        rbac.grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        rbac.renounceRole(DEFAULT_ADMIN_ROLE, admin);
        vm.stopPrank();

        vm.prank(newAdmin);
        rbac.grantRole(DEBT_MANAGER_ROLE, admin);
        assertEq(rbac.getRoleMember(DEBT_MANAGER_ROLE, 0), admin);

        vm.prank(admin);
        rbac.setDebt(token, _info(1));
        assertTrue(rbac.hasDebt(token));
    }

    /*//////////////////////////////////////////////////////////////
              AC-4 — last admin renounces (F-3)
    //////////////////////////////////////////////////////////////*/

    /// @notice AC-4 / F-3: after the only admin renounces, no role can ever be granted again.
    function testLastAdminRenounceFreezesRoles() public {
        vm.prank(admin);
        rbac.renounceRole(DEFAULT_ADMIN_ROLE, admin);
        assertEq(rbac.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 0);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, admin, DEFAULT_ADMIN_ROLE)
        );
        vm.prank(admin);
        rbac.grantRole(DEBT_MANAGER_ROLE, newAdmin);
    }

    /*//////////////////////////////////////////////////////////////
              MTX — trusted forwarder (F-2)
    //////////////////////////////////////////////////////////////*/

    /// @notice MTX-2 / F-2 PoC: the trusted forwarder can act as the admin for role management, not only data writes.
    function testPoC_F2_ForwarderCanGrantAdminRole() public {
        address attacker = address(0xBAD);
        bytes memory data = abi.encodeCall(IAccessControl.grantRole, (DEFAULT_ADMIN_ROLE, attacker));
        vm.prank(forwarder);
        (bool ok,) = address(rbac).call(abi.encodePacked(data, admin));
        assertTrue(ok);
        assertTrue(rbac.hasRole(DEFAULT_ADMIN_ROLE, attacker));
    }

    /// @notice MTX-2 / F-2 PoC (Ownable): the forwarder can start an ownership transfer on behalf of the owner.
    function testPoC_F2_ForwarderCanStartOwnershipTransfer() public {
        address attacker = address(0xBAD);
        vm.prank(forwarder);
        (bool ok,) = address(owned).call(abi.encodePacked(abi.encodeCall(Ownable.transferOwnership, (attacker)), admin));
        assertTrue(ok);
        assertEq(owned.pendingOwner(), attacker);
    }

    /// @notice MTX-1: the forwarder relays clearDebt for an authorized signer.
    function testForwarderRelaysClearDebt() public {
        vm.prank(admin);
        rbac.setDebt(token, _info(7));

        vm.prank(forwarder);
        (bool ok,) = address(rbac).call(abi.encodePacked(abi.encodeCall(DebtEngineBase.clearDebt, (token)), admin));
        assertTrue(ok);
        assertFalse(rbac.hasDebt(token));
    }

    /*//////////////////////////////////////////////////////////////
              DATA-2 — clear accepts address(0) (F-4)
    //////////////////////////////////////////////////////////////*/

    /// @notice DATA-2 / F-4 (fixed): clear functions reject address(0), like the setters, in both variants.
    /// Inverted from the PoC that asserted they accepted it.
    function testCannotClearAddressZero() public {
        DebtEngineBase[2] memory engines = [DebtEngineBase(rbac), DebtEngineBase(owned)];
        for (uint256 i = 0; i < engines.length; ++i) {
            vm.startPrank(admin);
            vm.expectRevert(SmartContractWithAddressZeroNotAllowed.selector);
            engines[i].clearDebt(address(0));
            vm.expectRevert(SmartContractWithAddressZeroNotAllowed.selector);
            engines[i].clearCreditEvents(address(0));
            vm.stopPrank();
        }
    }

    /*//////////////////////////////////////////////////////////////
              DATA-3 — engine shadows token-local data (F-5)
    //////////////////////////////////////////////////////////////*/

    function _deployToken() internal returns (CMTATStandaloneDebt cmtat) {
        cmtat = new CMTATStandaloneDebt(
            admin,
            ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", 0),
            ICMTATConstructor.ExtraInformationAttributes(
                "CMTAT_ISIN", IERC1643CMTAT.DocumentInfo("terms", "https://cmta.ch", bytes32(0)), "CMTAT_info"
            ),
            ICMTATConstructor.Engine(IRuleEngine(address(0)), ISnapshotEngine(address(0)), IERC1643(address(0)))
        );
    }

    /// @notice DATA-3 / F-5 PoC: a token's own debt disappears from `debt()` as soon as it points at an engine
    /// that holds no record for it.
    function testPoC_F5_EngineShadowsTokenLocalDebt() public {
        CMTATStandaloneDebt cmtat = _deployToken();
        vm.startPrank(admin);
        cmtat.setDebt(_info(1000));
        assertEq(cmtat.debt().debtInstrument.parValue, 1000);

        cmtat.setDebtEngine(rbac);
        vm.stopPrank();

        assertFalse(rbac.hasDebt(address(cmtat)));
        assertEq(cmtat.debt().debtInstrument.parValue, 0, "token-local debt hidden by the engine");
    }

    /*//////////////////////////////////////////////////////////////
              AC-1 / I-1 — only authorized callers write (fuzz)
    //////////////////////////////////////////////////////////////*/

    function _assertAllWritersReject(DebtEngineBase engine, address caller) internal {
        address[] memory targets = new address[](1);
        targets[0] = token;
        ICMTATDebt.DebtInformation[] memory infos = new ICMTATDebt.DebtInformation[](1);
        ICMTATCreditEvents.CreditEvents[] memory credits = new ICMTATCreditEvents.CreditEvents[](1);

        vm.startPrank(caller);
        vm.expectRevert();
        engine.setDebt(token, _info(1));
        vm.expectRevert();
        engine.setDebtBatch(targets, infos);
        vm.expectRevert();
        engine.clearDebt(token);
        vm.expectRevert();
        engine.setCreditEvents(token, _credit());
        vm.expectRevert();
        engine.setCreditEventsBatch(targets, credits);
        vm.expectRevert();
        engine.clearCreditEvents(token);
        vm.stopPrank();
    }

    /// @notice AC-1 / I-1: any caller that is not the admin / owner is rejected by all six writers, in both variants,
    /// with the variant's own unauthorized error.
    function testFuzz_OnlyAuthorizedCanWrite(address caller) public {
        vm.assume(caller != admin && caller != forwarder);

        _assertAllWritersReject(rbac, caller);
        _assertAllWritersReject(owned, caller);

        // The specific errors, on one path per variant
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, DEBT_MANAGER_ROLE)
        );
        vm.prank(caller);
        rbac.clearDebt(token);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        vm.prank(caller);
        owned.clearCreditEvents(token);

        assertFalse(rbac.hasDebt(token));
        assertFalse(owned.hasCreditEvents(token));
    }

    /*//////////////////////////////////////////////////////////////
              I-2 / I-3 — set / clear sequences match a model (fuzz)
    //////////////////////////////////////////////////////////////*/

    /// @notice I-2 / I-3: after any sequence of set / clear operations, hasDebt and debt() equal a simple model.
    function testFuzz_SetClearSequenceMatchesModel(uint256 ops, uint8 length) public {
        length = uint8(bound(length, 1, 32));
        bool modelSet;
        uint256 modelPar;

        vm.startPrank(admin);
        for (uint256 i = 0; i < length; ++i) {
            if ((ops >> i) & 1 == 1) {
                uint256 par = uint256(keccak256(abi.encode(ops, i)));
                rbac.setDebt(token, _info(par));
                modelSet = true;
                modelPar = par;
            } else {
                rbac.clearDebt(token);
                modelSet = false;
                modelPar = 0;
            }
            assertEq(rbac.hasDebt(token), modelSet);
            assertEq(rbac.debt(token).debtInstrument.parValue, modelPar);
        }
        vm.stopPrank();
    }
}
