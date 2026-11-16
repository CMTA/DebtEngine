# DebtEngine Codebase Feedback (v3)

## Scope

- `src/DebtEngineBase.sol`
- `src/DebtEngineInvariantStorage.sol`
- `src/deployment/DebtEngineAccessControl.sol`
- `src/deployment/DebtEngineOwnable.sol`

---

## Resolved from Initial Audit (v1)

| # | Finding | Status |
|---|---------|--------|
| 1 | Missing events on state changes | **Resolved** — `DebtSet` and `CreditEventsSet` events emitted |
| 2 | `/*` instead of `/**` for NatSpec | **Resolved** |
| 3 | Self-referencing batch NatSpec | **Resolved** — now references `{setCreditEvents}` / `{setDebt}` |
| 4 | Redundant memory variable in getters | **Resolved** — returns directly from mapping |
| 6 | `DebtEngineInvariantStorage` should be `abstract` | **Resolved** |
| 7 | Unused / redundant imports | **Resolved** |
| 9 | No zero-address check on `smartContract_` | **Resolved** — checks added with `SmartContractWithAddressZeroNotAllowed` |
| 10 | No way to distinguish "not set" from "empty" | **Resolved** — `hasDebt()` / `hasCreditEvents()` added |

---

## Resolved from Post-Refactor Audit (v2)

| # | Finding | Status |
|---|---------|--------|
| 1 | Admin super-role via `hasRole` override | **Resolved** — NatSpec added to `hasRole`, documented in README |
| 2 | No batch size limit | **Resolved** — `MAX_BATCH_SIZE = 500` with `BatchSizeTooLarge` error |
| 6 | Function modifier ordering convention | **Resolved** — changed to `internal view override` |
| 7 | ERC2771 forwarder is immutable | **Resolved** — documented in README |
| 8 | Test function names contain `ADDRESS_ZERO` | **Resolved** — renamed to camelCase |

---

## Open Findings

### 1. `renounceOwnership()` Permanently Bricks the Ownable Variant

**Severity: Low / Design**
**File:** `src/deployment/DebtEngineOwnable.sol`

After calling `renounceOwnership()`, the owner becomes `address(0)` and no one can ever call `setDebt`, `setCreditEvents`, or their batch versions again. There is no recovery mechanism.

This is inherent to OZ's `Ownable`, but particularly impactful here since the DebtEngine manages financial instrument metadata that may need future updates.

**Recommendation:** Consider overriding `renounceOwnership()` to revert, or document this risk prominently.

---

### 2. No Delete / Reset Functionality

**Severity: Low / Design**
**File:** `src/DebtEngineBase.sol`

Once debt or credit events are set for a smart contract address, there is no way to clear or reset them. The `_debtSet` and `_creditEventsSet` flags can never be set back to `false`.

If an issuer needs to disassociate debt data from a contract (e.g. after a migration or error), the only option is to overwrite with empty-ish values, but `hasDebt()` / `hasCreditEvents()` will still return `true`.

**Recommendation:** Consider adding `removeDebt(address)` and `removeCreditEvents(address)` functions that delete the mapping entries and reset the flags.

---

### 3. Unchecked Loop Counter in Batch Functions

**Severity: Gas**
**File:** `src/DebtEngineBase.sol:125, 149`

The loop counters in `setCreditEventsBatch` and `setDebtBatch` use checked arithmetic. Since `i` is bounded by `MAX_BATCH_SIZE` (500), overflow is impossible. `unchecked { ++i }` saves ~60 gas per iteration.

```solidity
// Current
for (uint256 i = 0; i < smartContracts.length; i++) {

// Optimized
for (uint256 i = 0; i < smartContracts.length;) {
    // ...
    unchecked { ++i; }
}
```

---

## Summary

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| 1 | `renounceOwnership()` permanently bricks Ownable variant | Low | Open |
| 2 | No delete / reset functionality | Low | Open |
| 3 | Unchecked loop counter in batch functions | Gas | Open |
