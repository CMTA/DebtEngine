# Slither report — feedback (DebtEngine v0.3.0)

Report: [slither-report.md](./slither-report.md) · Overview: [../AUDIT_OVERVIEW.md](../AUDIT_OVERVIEW.md)

| | |
|---|---|
| Tool | Slither 0.11.6 |
| Command | `slither . --compile-force-framework foundry --checklist --filter-paths "openzeppelin-contracts\|test\|CMTAT\|forge-std\|script"` |
| Scope | `src/` (5 files); mocks: none in the project; dependencies (`lib/`), tests and `script/` excluded |
| Commit | `3b86328`, 2026-11-17 |

## Executive triage

**No finding is exploitable and nothing needs fixing.** Slither reports 2 Informational results, both the same `dead-code` detector on a compiler-required override.

## Findings

| ID | Detector | Severity | Location | Disposition | Reason |
|---|---|---|---|---|---|
| ID-0 | `dead-code` | Informational | `src/deployment/DebtEngineAccessControl.sol:65-67` (`_msgData`) | By design | Required override: the contract inherits `Context` through both `AccessControlEnumerable` and `ERC2771Context`, and solc rejects the contract without an explicit `_msgData` override (`Error (6480)`). Nothing in `src/` or in the OpenZeppelin `AccessControl` / `Ownable` code it inherits calls `_msgData` (OpenZeppelin only calls it from `AccessManaged`, which is not used), so the function is unreachable but cannot be removed |
| ID-1 | `dead-code` | Informational | `src/deployment/DebtEngineOwnable.sol:46-48` (`_msgData`) | By design | Same reason, with `Ownable2Step` and `ERC2771Context` |

The v0.3.0 code-quality review records the same pair as unreachable-but-required (coverage: the only uncovered functions are these two overrides), and a probe that moved the overrides into a shared module failed with `Error (6480)`.

## Delta from the previous report (v0.2.0-era report, `src/DebtEngine.sol`)

| Detector | Before | Now | Why |
|---|---|---|---|
| `dead-code` | 1 (`DebtEngine._msgData`) | 2 | The single contract was split into two deployment contracts; each carries its own required override |
| `solc-version` | 1 (`^0.8.20` has known severe issues, e.g. `VerbatimInvalidDeduplication`) | 0 | Pragma raised to `^0.8.27` (needed for `require` with custom errors); the build pins 0.8.33 |
| `similar-names` | 9 (`smartContract_` vs `smartContracts`) | 0 | Not reported by this run of Slither 0.11.6 on the refactored code; the parameter names are unchanged in substance and the finding was cosmetic |
| **Total** | **11** | **2** | |

## Environment note

The previous report could not be refreshed for most of the v0.3.0 cycle: the local `slither` launcher pointed at a Python 3.10 user install while the system `python3` is 3.14 (`ModuleNotFoundError: No module named 'slither'`). This run uses `uvx --from slither-analyzer slither …`, which installs Slither in an isolated cached environment. Slither runs `forge clean` and a forced rebuild as part of its Foundry compilation, so `out/` and `cache/` are rebuilt afterwards.
