# AI-assisted findings ↔ production code

This file links findings from AI-assisted reviews (`doc/tools/<version>/CLAUDE_ANALYSIS.md`) to the production code in `src/` they changed or explain. Production comments never cite these reports: their IDs restart each release and their paths move, while a deployed contract's comments cannot be corrected. The substance lives in the NatSpec; the link lives here.

## How to use

- Add one entry per code location whenever an AI-assisted finding changes code in `src/`, or explains why it must not change.
- Identify a finding by **report, release, ID and title**, since IDs are not stable across releases.
- Keep `file:line` current when a symbol moves.

## v0.3.0 — `doc/tools/v0.3.0/CLAUDE_ANALYSIS.md`

### S-1. `clearDebt` / `clearCreditEvents` — deleting a record and resetting `hasDebt` / `hasCreditEvents`

| | |
|---|---|
| Location | `src/DebtEngineBase.sol:146`, `clearDebt`; `src/DebtEngineBase.sol:155`, `clearCreditEvents`; `src/DebtEngineBase.sol:188`, `_clearDebt` / `_clearCreditEvents`; `src/DebtEngineBase.sol:78`, `hasDebt` / `hasCreditEvents` |
| Code | `function clearDebt(address smartContract_) external virtual onlyDebtManager {` |
| Comment now | `@notice Deletes the debt record of smartContract_; hasDebt returns false afterwards and debt(smartContract_) returns the zero struct, as before any record was set.` / `@dev Clearing a contract that has no record succeeds and still emits {DebtCleared}.` (same wording for credit events); `hasDebt`: `@notice Returns true if a debt record is currently set ...` / `@dev True after {setDebt} / {setDebtBatch}, false again after {clearDebt}.` |
| Finding | `CLAUDE_ANALYSIS.md` (v0.3.0) **U-1**, "Clearing a record" (also resolves **H-2**, "A record can never be removed; `hasDebt` stays `true` forever"): verdict *decide*, adopted |
| Change applied | Added `clearDebt` / `clearCreditEvents`, internal `_clearDebt` / `_clearCreditEvents`, events `DebtCleared` / `CreditEventsCleared`; gated by the existing `_authorizeSetDebt` / `_authorizeSetCreditEvents` hooks. `hasDebt` / `hasCreditEvents` now mean "currently set" instead of "ever set". No new storage; +617 / +587 runtime bytes. |
