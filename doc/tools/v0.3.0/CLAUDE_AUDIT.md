# DebtEngine v0.3.0 — Claude Security Audit Report

| | |
|---|---|
| Tool | Claude (Anthropic), driven by a set of custom smart-contract security-audit skills; the specific internal skills used are intentionally not enumerated here |
| Codebase | DebtEngine v0.3.0, commit `705208b` (branch `dev`) |
| Toolchain | solc 0.8.33, optimizer 200 runs, legacy pipeline, `evm_version = prague`; Foundry 1.5.0; CMTAT v3.0.0, OpenZeppelin Contracts v5.5.0 |
| Severity framework | Code4rena (High / Medium / Low / Info) |
| Date | 2026-11-16 |
| Nature | AI-assisted security review. It is **not** an audit by an audit company. |

## 1. Scope and methodology

**In scope:** every production source under `src/`:

- `src/DebtEngineBase.sol`
- `src/DebtEngineInvariantStorage.sol`
- `src/modules/VersionModule.sol`
- `src/deployment/DebtEngineAccessControl.sol`
- `src/deployment/DebtEngineOwnable.sol`

**Out of scope:** `lib/` (CMTAT, OpenZeppelin, forge-std) and `test/`. Dependency code is quoted where it executes behaviour of an in-scope contract.

**Method:**
- A threat model: actors, trust levels, and 20 threats with IDs.
- An enumeration of every privileged entry point and the guard it passes. The call graph was traced by hand, because Slither could not run in the review environment.
- A targeted review of each threat, with executable Foundry proofs of concept and fuzz tests.
- An adversarial self-review: a separate pass tried to dismiss or downgrade every finding against the code and the documentation.

## 2. Executive summary

**0 Critical, 0 High, 0 Medium, 0 Low, 4 Info.**

The engine holds no funds and makes no external calls. Every state-changing function is gated by an authorization hook, and fuzzing over arbitrary callers in both deployment variants found no unauthorized write path. The Info findings concern role bookkeeping when an account holds `DEFAULT_ADMIN_ROLE`, freezing on renounce, one consistency nit, and the documentation. Three of the four are resolved by documentation and one (F-4) by a code fix applied after the audit.

**Cleared hypotheses.** Each of these would have been High or Medium; each was tested and does not hold:

- **Unauthorized write.** Every one of the six writers (`setDebt`, `setDebtBatch`, `clearDebt`, `setCreditEvents`, `setCreditEventsBatch`, `clearCreditEvents`) rejects any caller that is not authorized, in both variants. This was fuzzed over arbitrary callers. In an earlier mutation run, removing any hook's modifier made the suite fail.
- **Role-separation bypass.** A debt manager cannot set or clear credit events, and a credit-events manager cannot touch debt.
- **Meta-transaction sender spoofing.** A caller that is not the trusted forwarder cannot impersonate an account by appending its address to the calldata.
- **Records stored under `address(0)`.** Both setters reject it.
- **Interface mismatch with CMTAT.** A real CMTAT v3.0.0 `CMTATStandaloneDebt` reads both record types through the engine.
- **Reentrancy, upgrade and initializer issues.** Not applicable: there are no external calls, no proxy and no initializer.

The test suite went from 124 to **136** tests, all passing. Two of the new tests are fuzz tests (256 runs each).

## 3. Findings

| ID | Finding | Severity | Status | Component | PoC |
|---|---|---|---|---|---|
| F-1 | Implicit-admin `hasRole` override breaks role grant / revoke bookkeeping | Info (downgraded from Low) | Documented; code fix proposed | `src/deployment/DebtEngineAccessControl.sol:41-53` | `testPoC_F1_GrantRoleToAdminIsSilentNoOp`, `testPoC_F1_RevokeRoleFromAdminEmitsButKeepsPower`, `testPoC_F1_AdminHandoverDropsSelfGrantedRole` |
| F-3 | Renouncing the last admin freezes role management | Info | Documented (by design) | OZ `AccessControl.renounceRole` | `testLastAdminRenounceFreezesRoles` |
| F-4 | `clearDebt` / `clearCreditEvents` accept `address(0)` | Info | ✅ Fixed | `src/DebtEngineBase.sol:188-202` | `testCannotClearAddressZero` (inverted PoC) |
| F-7 | README RBAC role table omits the clear functions | Info | Fixed (documentation) | `README.md` | — |

IDs F-2, F-5 and F-6 were dismissed in the adversarial review and are recorded in section 7. Line numbers refer to the audited commit `705208b`.

### F-1. Implicit-admin `hasRole` override breaks role grant / revoke bookkeeping — Info

- **Location:**
  - `src/deployment/DebtEngineAccessControl.sol:41-53` (`hasRole`).
  - Executed by `lib/openzeppelin-contracts/contracts/access/AccessControl.sol:181-206` (`_grantRole`, `_revokeRole`; OpenZeppelin v5.5.0).
  - Reached from `grantRole` (`:120-122`), `revokeRole` (`:135-137`) and `renounceRole` (`:155-161`).
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
  - **Monitoring is misled.** A tool that rebuilds role holders from events sees a `RoleRevoked` for an admin that still writes records, and never sees a "grant" an admin made to itself.
  - **An admin handover can drop an intended role.** Take the usual sequence: grant yourself the manager role, grant admin to a multisig, renounce admin. The old admin ends up with no manager role, because the first grant was a no-op. Operations stop until the new admin re-grants it.
- **Severity adjustment (Low → Info, adversarial review):**
  - The grant side was already documented in the README note on the super-admin: no `RoleGranted` event, and the admin is not enumerated.
  - Only the trusted admin is affected, and one re-grant by the new admin restores the lost role.
  - CMTAT's `AccessControlModule.hasRole` (`lib/CMTAT/contracts/modules/wrapper/security/AccessControlModule.sol:34-45`) uses the same override, so CMTAT tokens behave the same way.
  - What remained undocumented was the misleading `RoleRevoked` event and the handover trap.
- **Fix — Implemented (documentation, Option C):**
  - The README super-admin note now explains the revocation behaviour and gives the handover runbook: renounce `DEFAULT_ADMIN_ROLE` first, then have the new admin grant the manager role.
  - The `hasRole` NatSpec says the same.
  - `testF1_RunbookGrantAfterRenounceWorks` pins the runbook.
  - Contract behaviour is unchanged.
- **Fix code — Proposed, not implemented (Option A):** keep the super-admin semantics for checks, but make bookkeeping record only explicit membership.
  - **Tested:** compiled and run in a scratch copy. The three PoCs above fail, as intended, and the other 133 tests pass; +81 runtime bytes.
  - **Requirements:** `pragma ^0.8.28` (transient value types) and a Cancun-or-later chain.
  - **Behaviour change:** revoking a manager role from an admin becomes a silent no-op, so the README note would need rewriting.
  - **Risk:** the adversarial review found no reentrancy window. The `onlyRole` check runs before the flag is set, no external call happens while it is set, and a revert rolls the transient flag back.

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

  An alternative, **Option B**, drops the override and accepts the admin inside the hooks. That is not recommended: it diverges from CMTAT, and the hooks could no longer be a bare `onlyRole`.

  ```solidity
  function _authorizeSetDebt() internal view virtual override {
      if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
          _checkRole(DEBT_MANAGER_ROLE);
      }
  }
  ```

### F-3. Renouncing the last admin freezes role management — Info

- **Location:** `lib/openzeppelin-contracts/contracts/access/AccessControl.sol:155-161` (`renounceRole`, OZ v5.5.0); `src/deployment/DebtEngineAccessControl.sol` does not use `AccessControlDefaultAdminRules`.
- **Description and impact:** after the only `DEFAULT_ADMIN_ROLE` holder renounces, no role can be granted or revoked again. Existing managers keep writing, and the registry is frozen once they renounce too. At the audited commit the README described this for the Ownable variant only.

```solidity
// lib/openzeppelin-contracts/contracts/access/AccessControl.sol:155-161 (OZ v5.5.0)
function renounceRole(bytes32 role, address callerConfirmation) public virtual {
    if (callerConfirmation != _msgSender()) {
        revert AccessControlBadConfirmation();
    }

    _revokeRole(role, callerConfirmation); // ◀ the last DEFAULT_ADMIN_ROLE holder can leave; nobody can grant again
}
```

- **Fix:** no code fix. This is by design, since a registry may be meant to freeze. **Implemented (documentation):** the README RBAC note now says "If the last `DEFAULT_ADMIN_ROLE` holder renounces, roles can no longer be granted or revoked." A code alternative is OpenZeppelin `AccessControlDefaultAdminRules` (a delayed two-step admin transfer). It would change the constructor and the ABI, so it is not proposed.

### F-4. `clearDebt` / `clearCreditEvents` accept `address(0)` — Info

- **Location:** `src/DebtEngineBase.sol:146-157` (`clearDebt`, `clearCreditEvents`), `:188-202` (`_clearDebt`, `_clearCreditEvents`).
- **Description and impact:** the setters reject `address(0)`, the clear functions do not. No state changes (nothing can be stored under `address(0)`), but `DebtCleared(address(0))` / `CreditEventsCleared(address(0))` can be emitted. The NatSpec already says clearing an unset record succeeds and emits.

```solidity
// src/DebtEngineBase.sol:188-192
function _clearDebt(address smartContract_) internal virtual {
    // ◀ no address(0) check, unlike _setDebt (:168)
    delete _debts[smartContract_];
    delete _debtSet[smartContract_];
    emit DebtCleared(smartContract_);
}
```

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

### F-7. README RBAC role table omits the clear functions — Info

- **Location:** `README.md`, the "DebtEngineAccessControl (RBAC)" role table.
- **Description:** at the audited commit, `DEBT_MANAGER_ROLE` was described as "Can call `setDebt` and `setDebtBatch`", and the credit-events role the same way. This contradicted the capability table just above it, which includes `clearDebt` / `clearCreditEvents`. An operator granting the role from that table would not know that it also allows deleting records. This finding came out of the adversarial review.
- **Fix:** no code fix. **Implemented (documentation):** both rows now list the clear function.

## 4. Invariant verification

| Invariant | Property | Holds? | Evidence |
|---|---|---|---|
| I-1 | Only an authorized account changes `_debts`, `_creditEvents` or the `has*` flags | ✅ | `testFuzz_OnlyAuthorizedCanWrite` (256 runs; six writers × two variants, with the variant's specific error) |
| I-2 | `hasDebt(a)` is true iff the last write to `a` was a set | ✅ | `testFuzz_SetClearSequenceMatchesModel` (256 runs, sequences of up to 32 set / clear operations checked against a model) |
| I-3 | `debt(a)` equals the last record set, or the zero struct after a clear | ✅ | same, plus `testFuzz_SetDebtRoundTrip` / `testFuzz_SetCreditEventsRoundTrip` |
| I-4 | No record is stored under `address(0)`, and no clear accepts it | ✅ | `testCannotSetDebtForAddressZero`, `testCannotSetCreditEventsForAddressZero`, batch variants, `testCannotClearAddressZero` (F-4 fixed) |
| I-5 | A debt manager cannot change credit events, and vice versa | ✅ | `testDebtManagerCannotSetCreditEvents`, `testCreditEventsManagerCannotSetDebt`, `testDebtManagerCannotClearCreditEvents`, `testCreditEventsManagerCannotClearDebt` |
| I-6 | Without the trusted forwarder, `_msgSender() == msg.sender` | ✅ | `testUntrustedCallerCannotSpoofSender`, `testBaseMsgSenderIsMsgSender` |

## 5. Access-control verification

| Entry point | `DebtEngineAccessControl` | `DebtEngineOwnable` | Verified |
|---|---|---|---|
| `setDebt`, `setDebtBatch`, `clearDebt` | `DEBT_MANAGER_ROLE` (or admin) | owner | ✅ positive and negative tests, fuzzed callers |
| `setCreditEvents`, `setCreditEventsBatch`, `clearCreditEvents` | `CREDIT_EVENTS_MANAGER_ROLE` (or admin) | owner | ✅ |
| `grantRole` / `revokeRole` | `DEFAULT_ADMIN_ROLE` | — | ✅ (F-1 behaviour for admins) |
| `renounceRole` | the account itself | — | ✅ (F-3) |
| `transferOwnership` → `acceptOwnership` | — | owner → pending owner | ✅ two-step; `transferOwnership(address(0))` cancels a pending transfer |
| `renounceOwnership` | — | owner | ✅ freezes all records |
| Views (`debt`, `creditEvents`, `hasDebt`, `hasCreditEvents`, `version`, `supportsInterface`) | anyone | anyone | ✅ |

**Negative results:**
- A debt manager cannot touch credit events, and a credit-events manager cannot touch debt.
- Neither manager role can grant roles.
- A pending owner other than the nominated one cannot accept.
- A non-forwarder cannot spoof a sender.

**Centralization premise:**
- The default admin implicitly holds every role. This is inherent to the model (and to CMTAT), not a finding.
- The trusted forwarder is trusted for every function, role and ownership management included.
- A single admin or owner key can rewrite or delete every record.

## 6. Remediation — what was implemented

The documentation remediation landed in commit `e7be94b`; F-4 is the only code change, applied afterwards.

| Finding | Status | What changed | Verified by |
|---|---|---|---|
| F-1 | ⚠️ Documented, behaviour unchanged | README super-admin note: the admin-revocation behaviour and the handover runbook; `hasRole` NatSpec extended | `testF1_RunbookGrantAfterRenounceWorks`; the three `testPoC_F1_*` keep asserting the current behaviour |
| F-3 | ⚠️ Documented, behaviour unchanged | README RBAC note: renouncing the last admin freezes role management | `testLastAdminRenounceFreezesRoles` |
| F-7 | ✅ Fixed (documentation) | README RBAC role table lists `clearDebt` / `clearCreditEvents` | — |
| Forwarder trust (dismissed F-2) | ⚠️ Documented | README "Gasless support": the forwarder is trusted for every function, including role management and ownership transfer; use a signature-verifying forwarder or `address(0)` | `testPoC_F2_ForwarderCanGrantAdminRole`, `testPoC_F2_ForwarderCanStartOwnershipTransfer` |
| F-4 | ✅ Fixed (code) | `_clearDebt` / `_clearCreditEvents` reject `address(0)` with `SmartContractWithAddressZeroNotAllowed` (`src/DebtEngineBase.sol:192`, `:203`). Behaviour change: clearing `address(0)` now reverts instead of emitting an event | `testCannotClearAddressZero` (inverted PoC; fails with the checks removed) |
| F-1 Option A | ⬜ Declined for now | A design decision for the maintainers (compiler bump, divergence from CMTAT) | Compiled and tested in a scratch copy only |

No breaking change to the ABI or storage was introduced; F-4 adds a revert path to `clearDebt` / `clearCreditEvents` for `address(0)` only.

## 7. Potential improvements (open backlog)

These are hardening and documentation items, not vulnerabilities.

| # | Improvement | Addresses | Effort | Breaking? | Priority |
|---|---|---|---|---|---|
| 1 | Adopt F-1 Option A so that role bookkeeping records explicit membership | F-1 | Small (code and tests exist) | Behavioural: revoking from an admin becomes a no-op; needs solc ≥ 0.8.28, Cancun+ | **Design decision** |
| 2 | README integration note: write the engine record before `setDebtEngine` on the token; integrators use `hasDebt(token)` to tell "empty" from "unset" | dismissed F-5 | Trivial | No | Low |
| 3 | Re-run Slither once it can run in the review environment, and refresh `doc/tools/v0.3.0/slither-report.md` | tooling | Trivial | No | Low |

- **Item 1** is a choice between two consistent behaviours: today's, which matches CMTAT and is now documented, and exact bookkeeping. Neither is a defect.
- **Item 3** comes from CMTAT's fallback rule. A CMTAT token that points at the engine returns the engine's answer even when the engine holds no record for it, so the token's own data is hidden. DebtEngine cannot change this.

## 8. Scope and duplicate check

- **Scope:** every finding is in an in-scope contract, or in a dependency line those contracts execute (OZ v5.5.0, quoted with its version).
- **Duplicates:** no automated-analysis report ships with the project. The Slither and Aderyn reports in `doc/tools/v0.3.0/` report none of these findings. The v0.3.0 code-quality review (`CLAUDE_ANALYSIS.md`) raised the batch-size observation; it is listed below and is not counted again.
- **Considered and dismissed:**

| ID | Observation | Reason |
|---|---|---|
| F-2 | The trusted forwarder can perform admin actions (grant `DEFAULT_ADMIN_ROLE`, start an ownership transfer) | ERC-2771 trust model: the forwarder is fully trusted and immutable, and the README already says a compromised forwarder means redeploying; now stated explicitly (section 6) |
| F-5 | Pointing a CMTAT token at the engine hides the token's own `DebtModule` data | CMTAT `DebtEngineModule` behaviour (`lib/`, out of scope); the README notes the empty read after a clear; backlog item 3 |
| F-6 | Batches hit the per-transaction gas cap (EIP-7825) long before `MAX_BATCH_SIZE` | Already documented in the NatSpec and README; admin-only, and an oversized batch reverts without effect |
| AC-5 | Ownership lost through a mistyped transfer | `Ownable2Step` requires acceptance |
| AC-6 | A compromised admin, owner or manager rewrites records | Trusted actor |
| MTX-3 | `forwarder = address(0)` trusts some sender | `msg.sender` is never `address(0)` |
| DATA-4 | A duplicated address in a batch | Last write wins, two events; tested |
| DOS-2 | Oversized strings | Only trusted writers choose them, and they pay for them |
| INT-1 | Any party can read any token's record | Records are public by design (`debt(address)`) |
| STD-1 | Wrong ERC-165 advertisement | Interface ids pinned in tests for both variants |
| UPG-1 / REE-1 | Upgrade, initializer and reentrancy | Not applicable |
