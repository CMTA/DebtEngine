# Slither report — DebtEngine v0.3.0

| | |
|---|---|
| Tool | Slither 0.11.6 (run with `uvx --from slither-analyzer`) |
| Command | `slither . --compile-force-framework foundry --checklist --filter-paths "openzeppelin-contracts\|test\|CMTAT\|forge-std\|script" > doc/tools/v0.3.0/slither-report.md` |
| Scope | `src/` only (5 files); dependencies, tests and deployment scripts filtered out; the project has no mocks. Scope check: 0 `lib/` paths in the output |
| Date / commit | 2026-11-17, `3b86328` |
| Result | **0 High · 0 Medium · 0 Low · 2 Informational** |

| Detector | Severity | Instances | Assessment |
|---|---|---|---|
| `dead-code` | Informational | 2 | By design: `_msgData()` overrides in `DebtEngineAccessControl` / `DebtEngineOwnable` are required by the compiler (`Context` is inherited twice) and cannot be removed |

**Nothing to fix.** Triage: [slither-report-feedback.md](./slither-report-feedback.md) · Overview: [../AUDIT_OVERVIEW.md](../AUDIT_OVERVIEW.md)

---

'forge clean' running (wd: /home/ryan/Pictures/dev/DebtEngine)
'forge config --json' running
'forge build --build-info --deny never --skip ./test/** ./script/** --force' running (wd: /home/ryan/Pictures/dev/DebtEngine)
**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [dead-code](#dead-code) (2 results) (Informational)
## dead-code
Impact: Informational
Confidence: Medium
 - [ ] ID-0
[DebtEngineAccessControl._msgData()](src/deployment/DebtEngineAccessControl.sol#L65-L67) is never used and should be removed

src/deployment/DebtEngineAccessControl.sol#L65-L67


 - [ ] ID-1
[DebtEngineOwnable._msgData()](src/deployment/DebtEngineOwnable.sol#L46-L48) is never used and should be removed

src/deployment/DebtEngineOwnable.sol#L46-L48


