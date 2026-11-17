# Aderyn report — feedback (DebtEngine v0.3.0)

Report: [aderyn-report.md](./aderyn-report.md) · Overview: [../AUDIT_OVERVIEW.md](../AUDIT_OVERVIEW.md)

| | |
|---|---|
| Tool | Aderyn 0.6.5 |
| Command | `aderyn -x mocks --output doc/tools/v0.3.0/aderyn-report.md` |
| Scope | `src/` (5 files, 182 nSLOC) from the Foundry config; mocks: none in the project; 0 `lib/` paths in the output |
| Commit | `3b86328` + the F-4 fix, 2026-11-17 (re-run after the fix: same findings) |

## Executive triage

**No finding is exploitable and nothing needs fixing.** 0 High, 7 Low (25 instances); every instance was checked against the source and is by design, environment-dependent or a false positive.

## Findings

| ID | Finding | Instances | Locations | Disposition | Reason |
|---|---|---|---|---|---|
| L-1 | Centralization Risk | 6 | `DebtEngineAccessControl.sol:14, 25, 27`; `DebtEngineOwnable.sol:16, 34, 36` | By design | The engine is a registry written by trusted parties: `DEFAULT_ADMIN_ROLE` and the two manager roles, or the owner. Documented in the README (access-control section) and in the Claude security audit (centralization premise) |
| L-2 | Unspecific Solidity Pragma | 5 | line 2 of every file in `src/` | By design | `^0.8.27` is the minimum for `require(condition, CustomError())` on the legacy pipeline and lets integrators compile with newer solc; the project itself pins solc 0.8.33 in `foundry.toml` and `hardhat.config.js` |
| L-3 | PUSH0 Opcode | 5 | line 2 of every file in `src/` | Environment | The build targets `evm_version = prague`. Chains without PUSH0 (pre-Shanghai) need `evm_version` lowered at deployment; no code change |
| L-4 | Empty Block | 4 | `DebtEngineAccessControl.sol:25, 27`; `DebtEngineOwnable.sol:34, 36` | By design | The authorization hooks have an empty body on purpose: the check is the modifier (`onlyRole(...)` / `onlyOwner`). Removing a modifier fails the test suite (mutation-tested) |
| L-5 | Loop Contains `require`/`revert` | 2 | `DebtEngineBase.sol:120` (`setCreditEventsBatch`), `:136` (`setDebtBatch`) | By design | The zero-address check runs per entry inside `_setDebt` / `_setCreditEvents`; an invalid entry must revert the whole batch rather than be skipped silently |
| L-6 | Costly operations inside loop | 2 | `DebtEngineBase.sol:120`, `:136` | By design | Each entry is one record write, which is the purpose of a batch. Bounded by `MAX_BATCH_SIZE` (500) and, in practice, by the per-transaction gas cap (documented in the NatSpec and README) |
| L-7 | Unchecked Return | 1 | `DebtEngineAccessControl.sol:20` (`_grantRole(DEFAULT_ADMIN_ROLE, admin)`) | False positive | In the constructor the role cannot be held yet, so `_grantRole` always returns `true`; `testRoleMembersAreEnumerable` checks the admin is the `DEFAULT_ADMIN_ROLE` member |

## Delta from the previous v0.3.0 run (commit `df79202`)

| Finding | Before | Now | Change |
|---|---|---|---|
| L-1 … L-4, L-7 | same instances | same instances | None |
| L-5, L-6 | `DebtEngineBase.sol:116`, `:132` | `:120`, `:136` | Line shift only: the clear-functions commit (`705208b`) added the `DebtCleared` / `CreditEventsCleared` events and two NatSpec lines above the batch functions |

The `clearDebt` / `clearCreditEvents` functions added since the previous run produce no new finding.
