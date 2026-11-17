# DebtEngine — audit and analysis overview

> DebtEngine has **not been audited by an audit company**. The analyses below are static-analysis runs and AI-assisted reviews.

**In scope:** the production sources under `src/` (`DebtEngineBase`, `DebtEngineInvariantStorage`, `modules/VersionModule`, `deployment/DebtEngineAccessControl`, `deployment/DebtEngineOwnable`). Dependencies (`lib/`: CMTAT, OpenZeppelin, forge-std), tests and deployment scripts are out of scope.

## Analyses

| Version | Analysis | Report | Triage |
|---|---|---|---|
| v0.3.0 | Slither 0.11.6 | [slither-report.md](./v0.3.0/slither-report.md) | [slither-report-feedback.md](./v0.3.0/slither-report-feedback.md) |
| v0.3.0 | Aderyn 0.6.5 | [aderyn-report.md](./v0.3.0/aderyn-report.md) | [aderyn-report-feedback.md](./v0.3.0/aderyn-report-feedback.md) |
| v0.3.0 | Claude security audit (AI-assisted) | [CLAUDE_AUDIT.md](./v0.3.0/CLAUDE_AUDIT.md) | in the report |
| v0.3.0 | Claude code-quality review (AI-assisted) | [CLAUDE_ANALYSIS.md](./v0.3.0/CLAUDE_ANALYSIS.md) | in the report |
| v0.3.0 | Test coverage (`forge coverage`) | [doc/coverage](../coverage/coverage/index.html) | — |

## Static analysis, v0.3.0 (commit `3b86328` + the F-4 fix)

| Tool | High | Medium | Low | Info | Relevant to fix? |
|---|---|---|---|---|---|
| Slither 0.11.6 | 0 | 0 | 0 | 2 | **No** — both `dead-code` results are the compiler-required `_msgData` overrides |
| Aderyn 0.6.5 | 0 | — | 7 (25 instances) | — | **No** — centralization, pragma, PUSH0, hook idiom, bounded batch loops: by design or environment; one false positive |

## Test coverage, v0.3.0

| File | Lines | Branches | Functions |
|---|---|---|---|
| `DebtEngineBase.sol` | 100% (52/52) | 100% (16/16) | 100% (19/19) |
| `deployment/DebtEngineAccessControl.sol` | 86.67% (13/15) | 100% (3/3) | 85.71% (6/7) |
| `deployment/DebtEngineOwnable.sol` | 80.00% (8/10) | 100% (0/0) | 83.33% (5/6) |
| `modules/VersionModule.sol` | 100% (2/2) | 100% (0/0) | 100% (1/1) |
| **Total** | **94.94% (75/79)** | **100% (19/19)** | **93.94% (31/33)** |

The only uncovered functions are the two `_msgData` overrides, which the compiler requires and nothing calls. 154 tests, including fuzz tests and mutation-verified access-control tests.

## Findings from the AI-assisted reviews

Claude security audit, v0.3.0: **0 Critical, 0 High, 0 Medium, 0 Low, 4 Info.**

| ID | Severity | Finding | Status |
|---|---|---|---|
| F-1 | Info | An admin passes every role check, so granting it a manager role is a no-op and revoking one emits `RoleRevoked` without effect | Documented (runbook in README and the deployment guide); code fix proposed |
| F-3 | Info | Renouncing the last admin freezes role management | Documented (by design) |
| F-4 | Info | `clearDebt` / `clearCreditEvents` accepted `address(0)` | Fixed (code): they now revert with `SmartContractWithAddressZeroNotAllowed` |
| F-7 | Info | README role table omitted the clear functions | Fixed |

The code-quality review changes that landed in v0.3.0 (single write paths, `virtual` public API, `require` guards, ERC-165 for the Ownable variant, documented batch gas limits) are listed in its disposition table.
