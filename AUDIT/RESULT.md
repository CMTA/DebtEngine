# DebtEngine v0.3.0 — Security Analysis Results

## Run options

| Option | Value | Source |
|---|---|---|
| `--mode` | `full` — new tests in `test/DebtEngineThreatModel.t.sol` | asked |
| `--scope` | `all` — the five files under `src/` (no scope file; `lib/`, `test/` out of scope) | asked (`auto` → `all`) |
| `--out` | `AUDIT/` | asked |
| `--judge` | `on` | asked |

Audited commit `705208b` (branch `dev`); solc 0.8.33, optimizer 200, no `via_ir`, `prague`; Foundry 1.5.0; CMTAT v3.0.0, OpenZeppelin v5.5.0. Tests were run natively with Foundry, not in Docker (a Solidity/Foundry project; the generic entrypoint exempts it). Produced with Claude Code: an AI-assisted analysis, not an audit by an audit company.

## Claude Skills Used

| Skill | Findings contributed |
|---|---|
| `audit-access-control` | F-1, F-3, NAF AC-1, AC-2, AC-5, AC-6 |
| `openzeppelin-v5` | F-1 (role bookkeeping calls the overridden `hasRole`), F-2 |
| `cmtat` | F-5, NAF INT-1, INT-2 |
| `cmtat-audit` | Severity calibration (CMTA down-weights trusted-role issues); no prior finding on F-1 |
| `erc173-ownership` | NAF AC-5 |
| `sc-analyse-and-test`, `sc-analyse-and-test-solidity` | Workflow |
| `qalc` | Not needed: no value computed outside the code |

## Test Execution Summary

| Suite | Tests | Result |
|---|---|---|
| `DebtEngineAccessControlTest` (shared suite + RBAC) | 64 | pass |
| `DebtEngineOwnableTest` (shared suite + Ownable) | 58 | pass |
| `DebtEngineHarnessTest` | 2 | pass |
| **`DebtEngineThreatModelTest` (new)** | **12** | pass |
| **Total** | **136** (baseline 124) | 0 failed |

New tests (`test/DebtEngineThreatModel.t.sol`):

| Test | Type | Threat | Gas / runs |
|---|---|---|---|
| `testPoC_F1_GrantRoleToAdminIsSilentNoOp` | Unit PoC | AC-3 | 24,013 |
| `testPoC_F1_RevokeRoleFromAdminEmitsButKeepsPower` | Unit PoC | AC-3 | 143,760 |
| `testPoC_F1_AdminHandoverDropsSelfGrantedRole` | Integration PoC | AC-3 | 98,156 |
| `testF1_RunbookGrantAfterRenounceWorks` | Integration | AC-3 | 293,730 |
| `testLastAdminRenounceFreezesRoles` | Unit | AC-4 | 31,797 |
| `testPoC_F2_ForwarderCanGrantAdminRole` | Unit PoC | MTX-2 | 94,350 |
| `testPoC_F2_ForwarderCanStartOwnershipTransfer` | Unit PoC | MTX-2 | 40,602 |
| `testForwarderRelaysClearDebt` | Unit | MTX-1 | 105,748 |
| `testClearAcceptsAddressZero` → `testCannotClearAddressZero` (inverted after the F-4 fix) | Unit | DATA-2 | 67,772 (before inversion) |
| `testPoC_F5_EngineShadowsTokenLocalDebt` | Integration PoC (real `CMTATStandaloneDebt`) | DATA-3 | 5,396,953 |
| `testFuzz_OnlyAuthorizedCanWrite` | Fuzz, both variants, six writers | AC-1 / I-1 | 256 runs |
| `testFuzz_SetClearSequenceMatchesModel` | Fuzz, model check over ≤ 32 ops | I-2 / I-3 | 256 runs |

## Findings

### Findings Summary Table

| ID | Short Description | Severity | Status | Component | Skill | PoC | In-Scope |
|---|---|---|---|---|---|---|---|
| F-1 | Implicit admin breaks role grant/revoke bookkeeping | INFO (was LOW, judge) | Confirmed; docs fixed | `src/deployment/DebtEngineAccessControl.sol:41-53` (at `705208b`; `:43-55` after this run's NatSpec edit) | `openzeppelin-v5` | `testPoC_F1_*` (3) | ✅ |
| F-2 | Immutable forwarder can perform admin actions | — (was INFO, judge) | NOT-A-FINDING: ERC-2771 trust assumption; README note added | `DebtEngineAccessControl.sol:18`, `DebtEngineOwnable.sol:20` | `openzeppelin-v5` | `testPoC_F2_*` (2) | ✅ |
| F-3 | Last admin renounce freezes role management | INFO | By-design; README note added | OZ `AccessControl.renounceRole` | `audit-access-control` | `testLastAdminRenounceFreezesRoles` | ✅ |
| F-4 | Clear functions accept `address(0)` | INFO | Fixed after the audit (`testCannotClearAddressZero`) | `src/DebtEngineBase.sol:188-202` | Independent analysis | `testClearAcceptsAddressZero` | ✅ |
| F-5 | Engine shadows token-local debt once set | — (was INFO, judge) | NOT-A-FINDING: CMTAT behaviour, out of scope; README already notes the empty read after clear | CMTAT `DebtEngineModule.sol:64-71` | `cmtat` | `testPoC_F5_EngineShadowsTokenLocalDebt` | integration |
| F-6 | Batches hit the EIP-7825 gas cap first | — (was INFO, judge) | NOT-A-FINDING: already documented | `src/DebtEngineBase.sol:23-29` | Independent analysis | v0.3.0 quality review H-1 | ✅ |
| F-7 | README RBAC role table omits `clearDebt` / `clearCreditEvents` | INFO (found by judge) | Confirmed; fixed | `README.md` role table | Agent judge | — | ✅ |
| AC-1 | Writer reachable without its hook | — | NOT-A-FINDING | `DebtEngineBase.sol:94-157` | `audit-access-control` | `testFuzz_OnlyAuthorizedCanWrite` | ✅ |
| AC-2 | Role separation bypass | — | NOT-A-FINDING | `DebtEngineAccessControl.sol:25-27` | `audit-access-control` | `test*ManagerCannot*` (4) | ✅ |
| AC-5 | Ownership lost by mistyped transfer | — | NOT-A-FINDING | `Ownable2Step` | `erc173-ownership` | `testTransferOwnershipIsTwoStep` | ✅ |
| AC-6 | Compromised admin/owner/manager rewrites records | — | NOT-A-FINDING | trusted actor | `cmtat-audit` | — | ✅ |
| MTX-1 | Non-forwarder spoofs the sender | — | NOT-A-FINDING | OZ `ERC2771Context.sol:55-65` | `openzeppelin-v5` | `testUntrustedCallerCannotSpoofSender` | ✅ |
| MTX-3 | `forwarder = address(0)` trusts a sender | — | NOT-A-FINDING | OZ `ERC2771Context` | `openzeppelin-v5` | — | ✅ |
| DATA-1 | Record written for `address(0)` | — | NOT-A-FINDING | `DebtEngineBase.sol:168,179` | Independent analysis | `testCannotSet*ForAddressZero` | ✅ |
| DATA-4 | Duplicate address in a batch | — | NOT-A-FINDING | batch setters | Independent analysis | `testDuplicateAddressInDebtBatchLastWriteWins` | ✅ |
| DOS-2 | Oversized strings | — | NOT-A-FINDING | trusted writer | Independent analysis | — | ✅ |
| INT-1 | Third party reads another token's record | — | NOT-A-FINDING | `debt(address)` | `cmtat` | `testDebtForCallerThroughTrustedForwarder` | ✅ |
| INT-2 | `IDebtEngine` mismatch with CMTAT v3.0.0 | — | NOT-A-FINDING | `DebtEngineBase` | `cmtat` | `testCanReturnCMTATDebt` | ✅ |
| STD-1 | Wrong ERC-165 advertisement | — | NOT-A-FINDING | both `supportsInterface` | `openzeppelin-v5` | `testSupportsInterface` (both) | ✅ |
| UPG-1 | Initializer / storage collision | — | NOT-A-FINDING | — | — | — | N/A |
| REE-1 | Reentrancy | — | NOT-A-FINDING | — | — | — | N/A |

**Tally after the judge: 0 High, 0 Medium, 0 Low, 3 Info (F-1, F-3, F-4) + 1 documentation Info (F-7); 17 NOT-A-FINDING (14 initial + F-2, F-5, F-6).** Before the judge: 1 Low, 5 Info. No automated report (`4naly3er-report.md`) ships with the project, so no finding is a duplicate of one; the Slither and Aderyn reports in `doc/tools/v0.3.0/` do not report any of F-1..F-5.

### F-1. Implicit-admin `hasRole` override breaks role grant / revoke bookkeeping — INFO (downgraded from LOW by the judge)

- **Location:** `src/deployment/DebtEngineAccessControl.sol:41-53` (`hasRole`); executed by `lib/openzeppelin-contracts/contracts/access/AccessControl.sol:181-206` (`_grantRole`, `_revokeRole`, OpenZeppelin v5.5.0), reached from `grantRole` (`:120-122`), `revokeRole` (`:135-137`) and `renounceRole` (`:155-161`).
- **Identified by:** `openzeppelin-v5`.
- **Description:** `hasRole` returns `true` for any role when the account holds `DEFAULT_ADMIN_ROLE`. OpenZeppelin's `_grantRole` / `_revokeRole` use `hasRole` to decide whether membership changes, so for an admin:
  - `grantRole(DEBT_MANAGER_ROLE, admin)` stores nothing, emits no `RoleGranted`, and does not enumerate the admin;
  - `revokeRole(DEBT_MANAGER_ROLE, admin)` (or `renounceRole`) emits `RoleRevoked` although the admin keeps the power.

Problematic code:

```solidity
// src/deployment/DebtEngineAccessControl.sol:41-53
function hasRole(bytes32 role, address account)
    public
    view
    virtual
    override(AccessControl, IAccessControl)
    returns (bool)
{
    // The Default Admin has all roles
    if (AccessControl.hasRole(DEFAULT_ADMIN_ROLE, account)) { // ◀ also consulted by _grantRole / _revokeRole
        return true;
    }
    return AccessControl.hasRole(role, account);
}
```

```solidity
// lib/openzeppelin-contracts/contracts/access/AccessControl.sol:181-206 (OZ v5.5.0)
function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
    if (!hasRole(role, account)) {            // ◀ true for an admin → grant skipped, no event
        _roles[role].hasRole[account] = true;
        emit RoleGranted(role, account, _msgSender());
        return true;
    } else {
        return false;
    }
}
...
function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
    if (hasRole(role, account)) {             // ◀ true for an admin → RoleRevoked emitted, power kept
        _roles[role].hasRole[account] = false;
        emit RoleRevoked(role, account, _msgSender());
        return true;
    } else {
        return false;
    }
}
```

- **Impact:** no unauthorized access, and no record changes without an authorized key. Two operational consequences:
  - **Monitoring is misled.** An indexer or a compliance dashboard that rebuilds role holders from events sees a `RoleRevoked` for an admin that still writes records (`testPoC_F1_RevokeRoleFromAdminEmitsButKeepsPower`), and never sees the "grant" an admin made to itself.
  - **An admin handover can drop an intended role.** The usual sequence (grant the manager role to yourself, grant admin to a multisig, renounce admin) leaves the old admin with no manager role, because the first grant was a no-op (`testPoC_F1_AdminHandoverDropsSelfGrantedRole`). Operations stop until the new admin re-grants it.
- **Judge adjustment (LOW → INFO):** the grant side is already documented (README note on the super-admin: no `RoleGranted` event, admin not enumerated), only the trusted admin is affected, nothing is lost that a single re-grant by the new admin does not restore, and CMTAT v3.0.0 uses the same override. The undocumented parts — the misleading `RoleRevoked` and the handover trap — make it a documentation gap. Option C is the proportionate remedy; Option A remains available if exact role bookkeeping is wanted (the judge found no reentrancy window: the `onlyRole` check runs before the flag is set, no external call happens while it is set, a revert rolls the transient flag back, and TSTORE works in the constructor; it needs `pragma ^0.8.28`, a Cancun-or-later chain, and a rewrite of the README note, since revoking a role from an admin would then be a silent no-op instead).
- **Implemented (documentation, Option C):** README super-admin note extended with the revocation behaviour and the handover runbook; `hasRole` NatSpec (`src/deployment/DebtEngineAccessControl.sol:33-42`) now says grants to an admin are no-ops and revocations emit `RoleRevoked` without effect. `testF1_RunbookGrantAfterRenounceWorks` pins the runbook.
- **Precedent:** CMTAT's `AccessControlModule.hasRole` (`lib/CMTAT/contracts/modules/wrapper/security/AccessControlModule.sol:34-45`) uses the same override, so CMTAT tokens behave the same way. `cmtat-audit` records no prior finding on it.
- **Fix code — Proposed, not implemented** (it changes role-management behaviour and the minimum compiler; maintainer decision). Two options:

  **Option A (preferred): keep the super-admin semantics for checks, record explicit membership in bookkeeping.** Compiled and run in a scratch copy: the three `testPoC_F1_*` tests fail (as intended) and the other 133 pass, including `testImplicitAdminIsNotEnumerated`; +81 runtime bytes (9,190 → 9,271). It needs `pragma ^0.8.28` (transient value types).

  ```solidity
  // src/deployment/DebtEngineAccessControl.sol
  /// @dev Set only while `_grantRole` / `_revokeRole` run, so they record explicit membership.
  bool private transient _explicitRolesOnly;

  function hasRole(bytes32 role, address account)
      public view virtual override(AccessControl, IAccessControl) returns (bool)
  {
      // The Default Admin has all roles, except while role bookkeeping runs (see _grantRole / _revokeRole)
      if (!_explicitRolesOnly && AccessControl.hasRole(DEFAULT_ADMIN_ROLE, account)) {
          return true;
      }
      return AccessControl.hasRole(role, account);
  }

  function _grantRole(bytes32 role, address account) internal virtual override returns (bool granted) {
      _explicitRolesOnly = true;
      granted = super._grantRole(role, account);
      _explicitRolesOnly = false;
  }

  function _revokeRole(bytes32 role, address account) internal virtual override returns (bool revoked) {
      _explicitRolesOnly = true;
      revoked = super._revokeRole(role, account);
      _explicitRolesOnly = false;
  }
  ```

  **Option B: drop the override and grant the admin in the hooks.** Standard `hasRole` (bookkeeping and enumeration exact), but `hasRole(DEBT_MANAGER_ROLE, admin)` becomes `false`, which diverges from CMTAT and from the current README; the hooks can no longer be a bare `onlyRole`:

  ```solidity
  function _authorizeSetDebt() internal view virtual override {
      if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
          _checkRole(DEBT_MANAGER_ROLE);
      }
  }
  ```

  **Option C (no code): document the runbook.** Add to the README note on the super-admin: "Granting or revoking a manager role on an account that holds `DEFAULT_ADMIN_ROLE` has no effect: the grant is not recorded, and a revocation emits `RoleRevoked` while the account keeps the power. When handing admin over, renounce `DEFAULT_ADMIN_ROLE` first and have the new admin grant the manager role afterwards." `testF1_RunbookGrantAfterRenounceWorks` pins that sequence.

### F-2. The immutable trusted forwarder can perform admin actions — NOT-A-FINDING (judge)

- **Location:** `src/deployment/DebtEngineAccessControl.sol:18`, `src/deployment/DebtEngineOwnable.sol:20` (constructors), sender extraction in `lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol:55-65` (OZ v5.5.0).
- **Identified by:** `openzeppelin-v5`.
- **Description:** `_msgSender()` is used by every check, including `grantRole`, `revokeRole`, `renounceRole`, `transferOwnership` and `acceptOwnership`, not only by the data writers. The forwarder therefore controls role and ownership management for any signer it relays, and it cannot be rotated.

```solidity
// lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol:55-61
function _msgSender() internal view virtual override returns (address) {
    uint256 calldataLength = msg.data.length;
    uint256 contextSuffixLength = _contextSuffixLength();
    if (calldataLength >= contextSuffixLength && isTrustedForwarder(msg.sender)) { // ◀ any call, incl. grantRole
        unchecked {
            return address(bytes20(msg.data[calldataLength - contextSuffixLength:]));
```

- **Impact:** a compromised or buggy forwarder (or a forwarder that does not verify signatures) can grant itself `DEFAULT_ADMIN_ROLE` or start an ownership transfer (`testPoC_F2_*`). This is the documented trust assumption of ERC-2771, so not a vulnerability; the README says the forwarder is immutable but not that it reaches role management.
- **Judge adjustment (INFO → NOT-A-FINDING):** full trust in the forwarder is the ERC-2771 model, and the README already says a compromised forwarder means redeploying. The judge also advised against the optional per-selector `_msgSender` rule: two notions of the sender in one contract add risk. Dropped.
- **Implemented (documentation):** added to the README "Gasless support" note: "The forwarder is trusted for every function, including `grantRole`, `revokeRole`, `renounceRole` and ownership transfer. Use a forwarder that verifies EIP-712 signatures (e.g. OpenZeppelin `ERC2771Forwarder`), or deploy with `address(0)` when meta-transactions are not needed." 

### F-3. Renouncing the last admin freezes role management — INFO

- **Location:** OZ `AccessControl.sol:155-161` (`renounceRole`), no `AccessControlDefaultAdminRules`.
- **Identified by:** `audit-access-control` (§A "Can the role be renounced?").
- **Description / impact:** after the only `DEFAULT_ADMIN_ROLE` holder renounces, no role can be granted or revoked again (`testLastAdminRenounceFreezesRoles`); existing managers keep writing, and the registry is frozen once they renounce too. The README already says renouncing ownership freezes the Ownable variant; it says nothing for the RBAC one.
- **Implemented (documentation):** by design (a registry may be meant to freeze); sentence added to the README RBAC note: "If the last `DEFAULT_ADMIN_ROLE` holder renounces, roles can no longer be granted or revoked." Code alternative (Proposed, not compiled): inherit OpenZeppelin `AccessControlDefaultAdminRules` for a delayed two-step admin transfer; this changes the constructor and the ABI.

### F-4. `clearDebt` / `clearCreditEvents` accept `address(0)` — INFO

- **Location:** `src/DebtEngineBase.sol:146-157` (`clearDebt`, `clearCreditEvents`), `:188-202` (`_clearDebt`, `_clearCreditEvents`).
- **Identified by:** Independent analysis.

```solidity
// src/DebtEngineBase.sol:188-192
function _clearDebt(address smartContract_) internal virtual {
    // ◀ no address(0) check, unlike _setDebt (:168)
    delete _debts[smartContract_];
    delete _debtSet[smartContract_];
    emit DebtCleared(smartContract_);
}
```

- **Impact:** none on state (nothing can be stored under `address(0)`); a `DebtCleared(address(0))` event could be emitted (PoC `testClearAcceptsAddressZero`, since inverted). The NatSpec already says clearing an unset record succeeds.
- **Fix code — Implemented** (after the audit, before release): `src/DebtEngineBase.sol:191-192` and `:202-203` (`_clearDebt`, `_clearCreditEvents`), so `clearDebt` / `clearCreditEvents` now revert with `SmartContractWithAddressZeroNotAllowed`, like the setters. Cost: +78 runtime bytes per deployment contract, about +28 gas per clear call.

  ```solidity
  // src/DebtEngineBase.sol:191-196
  function _clearDebt(address smartContract_) internal virtual {
      require(smartContract_ != address(0), SmartContractWithAddressZeroNotAllowed());
      delete _debts[smartContract_];
      delete _debtSet[smartContract_];
      emit DebtCleared(smartContract_);
  }
  // same first line in _clearCreditEvents (:202-203)
  ```

  Verified by `testCannotClearAddressZero` (both variants, both clear functions), inverted from the PoC that asserted the old behaviour; with the two checks removed, it is the one test that fails.

### F-5. Pointing a token at the engine hides the token's own debt — NOT-A-FINDING (judge)

- **Location:** `lib/CMTAT/contracts/modules/wrapper/options/DebtEngineModule.sol:64-71` (CMTAT v3.0.0, `debt()`; `creditEvents()` at `:49-56` is identical).
- **Identified by:** `cmtat`.

```solidity
// lib/CMTAT/contracts/modules/wrapper/options/DebtEngineModule.sol:64-71
function debt() public view virtual override(DebtModule) returns(DebtInformation memory debtInformation_){
    DebtModuleStorage storage $ = _getDebtModuleStorage();
    if(address($._debtEngine) != address(0)){
        debtInformation_ =  $._debtEngine.debt();   // ◀ engine answer even when it holds no record
    } else {
        debtInformation_ = DebtModule.debt();
    }
}
```

- **Impact:** a token with its own debt set through `DebtModule.setDebt` reports a zero struct as soon as `setDebtEngine(engine)` runs, until the engine holds a record for it; the same after `clearDebt` (`testPoC_F5_EngineShadowsTokenLocalDebt`). The token's `debt()` has no way to tell "unset" from "zero"; only `engine.hasDebt(token)` does.
- **Judge adjustment (INFO → NOT-A-FINDING):** the behaviour is CMTAT's `DebtEngineModule` (`lib/`, out of scope), and the README already says a token pointing at the engine reads an empty record after a clear. Kept as an integration note.
- **Fix:** no code fix in DebtEngine (the fallback rule is CMTAT's). Runbook for the README: "Write the token's record in the engine (`setDebt(token, …)`) before calling `setDebtEngine` on the token; after `clearDebt(token)`, the token reports an empty record until it is set again or the engine is removed from the token. Integrators should use `hasDebt(token)` to distinguish an empty record from no record."

### F-6. Batches hit the per-transaction gas cap first — NOT-A-FINDING (judge: already documented)

Already documented in `MAX_BATCH_SIZE`'s NatSpec (`src/DebtEngineBase.sol:23-29`) and the README (v0.3.0 quality review, H-1). Admin-only; an oversized batch reverts without effect. No further action.

### F-7. README RBAC role table omits the clear functions — INFO (found by the judge)

- **Location:** `README.md`, "DebtEngineAccessControl (RBAC)" role table.
- **Description:** `DEBT_MANAGER_ROLE` was described as "Can call `setDebt` and `setDebtBatch`" (same for credit events), contradicting the capability table just above it, which includes `clearDebt` / `clearCreditEvents`. An operator granting the role from that table would not know it also allows deleting records.
- **Implemented:** both rows now list the clear function.

### NOT-A-FINDING dispositions

- **AC-1** — all six writers pass `onlyDebtManager` / `onlyCreditEventsManager` (`DebtEngineBase.sol:94-157`); fuzzed over arbitrary callers in both variants (`testFuzz_OnlyAuthorizedCanWrite`), and earlier mutation runs showed removing any hook modifier fails the suite.
- **AC-2** — debt and credit-events hooks check different roles; four tests cover set and clear in both directions.
- **AC-5** — `Ownable2Step`; `transferOwnership(address(0))` cancels rather than renounces (documented, tested).
- **AC-6** — trusted actor (CMTA down-weights role-gated issues; keys must be protected).
- **MTX-1** — OZ appends-suffix check requires `isTrustedForwarder(msg.sender)`; `testUntrustedCallerCannotSpoofSender`.
- **MTX-3** — with `forwarder = address(0)`, `isTrustedForwarder` is true only for `msg.sender == address(0)`, which cannot occur.
- **DATA-1** — `_setDebt` / `_setCreditEvents` reject `address(0)` (`:168`, `:179`).
- **DATA-4** — last write wins and both events are emitted; documented by test.
- **DOS-2** — only trusted writers choose string sizes; the cost falls on them.
- **INT-1** — records are public by design (`debt(address)`).
- **INT-2** — the engine compiles against CMTAT v3.0.0 `IDebtEngine` and a real `CMTATStandaloneDebt` reads both records.
- **STD-1** — ERC-165 ids pinned in tests for both variants.
- **UPG-1 / REE-1** — not applicable (no proxy, no external call).

## Invariant verification

| Invariant | Holds | Evidence |
|---|---|---|
| I-1 only authorized accounts change records | ✅ | `testFuzz_OnlyAuthorizedCanWrite` (256 runs, both variants) |
| I-2 `hasDebt` ⇔ last write was a set | ✅ | `testFuzz_SetClearSequenceMatchesModel` (256 runs) |
| I-3 `debt()` = last record or zero struct | ✅ | same, plus `testFuzz_SetDebtRoundTrip` |
| I-4 no record under `address(0)` | ✅ | `testCannotSet*ForAddressZero`; clears too since the F-4 fix (`testCannotClearAddressZero`) |
| I-5 role separation | ✅ | `test*ManagerCannot*` |
| I-6 `_msgSender() == msg.sender` without forwarder | ✅ | `testUntrustedCallerCannotSpoofSender`, `testBaseMsgSenderIsMsgSender` |

## Access control verification

| Function | RBAC | Ownable | Tested |
|---|---|---|---|
| `setDebt`, `setDebtBatch`, `clearDebt` | `DEBT_MANAGER_ROLE` (or admin) | owner | ✅ |
| `setCreditEvents`, `setCreditEventsBatch`, `clearCreditEvents` | `CREDIT_EVENTS_MANAGER_ROLE` (or admin) | owner | ✅ |
| `grantRole` / `revokeRole` | `DEFAULT_ADMIN_ROLE` | — | ✅ (F-1 quirks) |
| `renounceRole` | self | — | ✅ |
| `transferOwnership` / `acceptOwnership` / `renounceOwnership` | — | owner / pending owner / owner | ✅ |
| Views | anyone | anyone | ✅ |

## Recommendations summary

| Priority | Item | Changes | Status |
|---|---|---|---|
| 1 | F-1: keep Option C (documented runbook), or adopt Option A for exact role bookkeeping | `src/deployment/DebtEngineAccessControl.sol` (`hasRole`, new `_grantRole` / `_revokeRole`) | Option C implemented (README, NatSpec); Option A proposed, compiled and tested in a scratch copy |
| 2 | F-3, F-7 and the forwarder note (F-2) | `README.md` | Implemented |
| 3 | F-4: zero-address check in `_clearDebt` / `_clearCreditEvents` | `src/DebtEngineBase.sol:192`, `:203` | Implemented |
| 4 | F-5: write the engine record before `setDebtEngine`; integrators use `hasDebt(token)` | `README.md` integration note | Proposed (text in F-5) |

## Agent judge

A separate agent re-checked every finding against the code and the README and ran the PoC suite (12/12 pass). Adjustments, all applied above:

| ID | Verdict | Severity before → after |
|---|---|---|
| F-1 | Downgrade: grant side already documented, inherited CMTAT convention, trusted admin only | LOW → INFO |
| F-2 | Dismiss: ERC-2771 trust model, already implied by the README | INFO → NOT-A-FINDING |
| F-3 | Stands | INFO |
| F-4 | Stands | INFO |
| F-5 | Dismiss: CMTAT behaviour, out of scope, already noted in the README | INFO → NOT-A-FINDING |
| F-6 | Dismiss: already documented | INFO → NOT-A-FINDING |
| F-7 | New: README role table omits clear functions | INFO |
| NAFs | All 14 agreed | — |

The judge confirmed that all 20 threats in `THREAT_MODEL.md` have a disposition here.

## Review completeness

**Setup (Step 0–1)**
- [x] Run options resolved (all four asked once by the entrypoint) and recorded at the top of `THREAT_MODEL.md` and `RESULT.md`.
- [x] Scope resolved to the five `src/` files; no out-of-scope file exists; the In-Scope column matches (F-5 marked "integration").
- [x] Toolchain recorded: solc 0.8.33, optimizer 200, no `via_ir`, `prague`, Foundry 1.5.0, CMTAT v3.0.0, OZ v5.5.0.
- [x] Baseline `forge build` / `forge test`: 124 tests, no pre-existing failure.
- [x] Every in-scope contract read in full. Slither printers **not run** (`ModuleNotFoundError: No module named 'slither'`); call graph traced by hand in `THREAT_MODEL.md`; `AUDIT/slither-graph/` left empty.
- [x] Skills invoked and listed in each deliverable.

**Threat model and test plan (Steps 2–3)**
- [x] 20 threats with IDs; trust model, actors, invariants, dependencies written.
- [x] SafeERC20 pass: N/A (no token interaction). Typo pass: no hit. Standardized views: `IDebtEngine` views and ERC-3643 `version()` are non-reverting. Selector completeness: all six writers gated, fuzzed.
- [x] `TEST_IMPROVEMENT.md` maps T-1..T-10 to threat IDs with priorities.

**Tests (Steps 4–5)**
- [x] 12 tests in `test/DebtEngineThreatModel.t.sol`, two fuzz tests (256 runs, `bound()` on the sequence length); key invariants I-1..I-6 covered.
- [x] Negative tests assert the specific error (selector and arguments); the fuzz writer test uses bare `expectRevert()` for the six-writer sweep and then pins the specific error per variant.
- [x] Full suite run: 136 tests, 0 failures (after the documentation edits too).
- [x] `report-only`: N/A (`full` mode).

**Findings (Step 5)**
- [x] Findings Summary Table first, closed by a tally (before and after the judge).
- [x] Every threat maps to a finding or a NOT-A-FINDING row (confirmed by the judge).
- [x] Every finding has a location, verbatim code where code is involved, fix code or doc text labelled Implemented / Proposed, and a PoC.
- [x] Cited lines re-verified; citations are for the audited commit `705208b`, with the one shift after this run's NatSpec edit noted (F-1).
- [x] Severity on the Code4rena scale; no automated report ships with the project, so no duplicate.

**Judge and wrap-up (Steps 6–7)**
- [x] Agent judge run; adjustments recorded on each finding and in the table above.
- [x] `CLAUDE.md` (= `AGENTS.md`) updated in place at the project root (standing notes kept): `AUDIT/` and the new test file added, F-1 / F-2 security notes.
- [x] This checklist appended.
