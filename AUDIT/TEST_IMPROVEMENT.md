# DebtEngine v0.3.0 — Test Improvement Plan

Run options: `--mode full --scope all --out AUDIT/ --judge on` (see `THREAT_MODEL.md`).

## Claude Skills Used

| Skill | Purpose / Contribution |
|---|---|
| `sc-analyse-and-test-solidity` | Test categories and structure |
| `audit-access-control` | Negative tests per guard, role lifecycle |
| `openzeppelin-v5` | Role-bookkeeping and forwarder test cases |

## Current coverage assessment

Baseline at `705208b`: **124 tests**, all green (3 suites: shared suite run on both variants, Ownable/RBAC specifics, harness). `forge coverage` from the v0.3.0 quality review: `DebtEngineBase` 100% lines / branches / functions; only the `_msgData` overrides are unreached.

Well covered: every guard with its exact error, set / batch / clear lifecycle, role separation for set and clear, batch boundaries (0, 500, 501, duplicates, length both ways), fuzzed write-then-read, forwarder relay / spoof, ERC-165, two-step ownership, CMTAT reading through the engine.

Missing:

| # | Test | Threat | Type |
|---|---|---|---|
| T-1 | Granting a manager role to an admin is a silent no-op (no event, not enumerated) | AC-3 | Unit (PoC) |
| T-2 | Revoking a manager role from an admin emits `RoleRevoked` but the admin keeps the power | AC-3 | Unit (PoC) |
| T-3 | Admin handover (grant new admin, renounce) drops the manager role the old admin "granted" itself; runbook that works | AC-3 | Integration (PoC) |
| T-4 | Last admin renounces: no role can be granted again, records frozen | AC-4 | Unit |
| T-5 | Trusted forwarder relaying a signer suffix can perform admin actions (`grantRole`) | MTX-2 | Unit (PoC) |
| T-6 | `clearDebt(address(0))` / `clearCreditEvents(address(0))` succeed and emit | DATA-2 | Unit |
| T-7 | Pointing a token at the engine hides the token's own `DebtModule` debt, before any engine record | DATA-3 | Integration (PoC, real `CMTATStandaloneDebt`) |
| T-8 | Any non-authorized caller is rejected by all six writers, both variants | AC-1 / I-1 | Fuzz |
| T-9 | Random set / clear sequences keep `hasDebt` and `debt()` equal to a model | I-2 / I-3 | Fuzz |
| T-10 | Forwarder relays `clearDebt` for an authorized signer | MTX-1 | Unit |

## Implementation priority

| Priority | Tests | Threats | Type |
|---|---|---|---|
| P1 | T-1, T-2, T-3 | AC-3 | PoC |
| P1 | T-8, T-9 | AC-1, I-1..I-3 | Fuzz |
| P2 | T-5, T-7 | MTX-2, DATA-3 | PoC |
| P3 | T-4, T-6, T-10 | AC-4, DATA-2, MTX-1 | Unit |

All in one file, `test/DebtEngineThreatModel.t.sol`.
