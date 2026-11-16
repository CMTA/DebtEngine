# DebtEngine v0.3.0 — Code Quality Review

| | |
|---|---|
| Scope | `src/` (`DebtEngineBase`, `DebtEngineInvariantStorage`, `modules/VersionModule`, `deployment/DebtEngineAccessControl`, `deployment/DebtEngineOwnable`) and `test/` |
| Baseline commit | `fac07f2` (branch `dev`), plus the uncommitted v0.3.0 work present at the start of the review |
| Compiler | solc 0.8.33, optimizer 200 runs, legacy pipeline (no `via_ir`), `evm_version = prague`; Foundry 1.5.0 |
| Dependencies | CMTAT v3.0.0, OpenZeppelin Contracts v5.5.0 |
| Date | 2026-11-16 |
| Mode | **Patching**: mechanical fixes applied, tests added; ✅ means *changed and verified*, ⬜ means *deliberately left as is* |
| Produced with | Claude Code (AI-assisted review — a working document, not an audit) |

**This is a code-quality review, not a security audit.** Nothing found lets an unauthorized party move value, bypass a restriction or brick a contract. The engine stores data written by authorized roles only; every write path is guarded by an authorization hook, and the hooks were mutation-tested (removing any of them fails the suite).

Baseline: `forge build` and `forge test` green at the start, **69 tests**. End: **104 tests**, all green, `forge fmt --check` clean.

## Disposition summary

| ID | Finding | Outcome |
|---|---|---|
| A-1 | Loops: `i++`, `calldata`, bounded iteration | ⬜ nothing to change |
| B-1 | Storage reads | ⬜ nothing to change |
| C-1 | `DebtSet` / `CreditEventsSet` each emitted from two places | ✅ single emit site via `_setDebt` / `_setCreditEvents` |
| C-2 | Events carry only the address, not the record | ⬜ keep |
| C-3 | Trusted forwarder set in the constructor without an event | ⬜ keep |
| D-1 | Write logic (check + store + flag + event) written four times | ✅ extracted (with C-1) |
| D-2 | ERC-2771 overrides duplicated in both deployment contracts | ⬜ keep — compiler requires them (probe: `Error 6480`) |
| E-1 | Public/external functions and context overrides not `virtual`, unlike hooks, `version()` and `hasRole` | ✅ all `virtual`, harness test |
| F-1 | `DebtEngineOwnable` does not advertise ERC-173 through ERC-165 (SHOULD) | ✅ `supportsInterface` added |
| F-2 | `IDebtEngine` interface id is `0x00000000` | ⬜ keep, do not advertise |
| F-3 | `transferOwnership(address(0))` does not renounce (ERC-173 deviation inherited from OpenZeppelin) | ✅ documented + test |
| G-1 | `pragma ^0.8.20` / README "0.8.20+" false once guards use `require` with custom errors | ✅ `^0.8.27` (corrected during the review, see M-1) |
| G-2 | README function table missing `version()`, `MAX_BATCH_SIZE`, `supportsInterface` | ✅ |
| G-3 | Agent guide: stale attribute-order rule; tool-report paths | ✅ |
| G-4 | Production-source reference scan; NatSpec length | ⬜ nothing found |
| H-1 | `MAX_BATCH_SIZE = 500` is unreachable under the mainnet transaction gas cap | ✅ documented; value → Outstanding |
| H-2 | A record can never be removed; `hasDebt` stays `true` forever | ✅ fixed by U-1 |
| H-3 | Renouncing ownership / admin freezes all records | ⬜ keep, documented |
| H-4 | `debt()` / `creditEvents()` answer for `_msgSender()`, so a forwarder can query any token | ⬜ keep (the data is public anyway) |
| I-1 | Interface granularity (`IDebtEngine`) | ⬜ nothing found |
| J-1 | `view` hooks block OpenZeppelin `AccessManaged.restricted` | ⬜ keep; view-only alternative compiles |
| J-2 | Legibility of names and directories | ⬜ keep |
| K-1 | Missing tests: batch-size guard, boundaries, forwarder, length direction | ✅ 35 tests added |
| L-1 | Braceless control-flow bodies | ⬜ none found |
| M-1 | `if`/`revert` guards | ✅ 9 converted to `require(cond, Error())` |
| U-1 | No way to clear a record | ✅ `clearDebt` / `clearCreditEvents` added |
| U-2 | No enumeration of the tokens that have a record | ⬜ leave |
| U-3 | No guidance on a batch size that fits in one transaction | ✅ documented (H-1) |

29 rows: 14 ✅, 15 ⬜.

## Outstanding

| ID | Item | Why it is still open |
|---|---|---|
| H-1 | Lower `MAX_BATCH_SIZE`, or keep 500 as a chain-agnostic ceiling | A design choice: 500 is harmless (an oversized batch runs out of gas and reverts), but a value near the mainnet limit (about 40 debt records) would catch mistakes earlier on mainnet and be wrong on chains with other caps. |
| — | Slither report in `doc/tools/v0.3.0/slither-report.md` predates this review | Slither cannot run on the review machine (`ModuleNotFoundError: No module named 'slither'`); re-run it after reinstalling. The Aderyn report was regenerated. |

## A. Loops and iteration

### A-1. Nothing to change

`setDebtBatch` (`src/DebtEngineBase.sol:124`) and `setCreditEventsBatch` (`:108`) iterate with `for (uint256 i = 0; i < smartContracts.length; i++)`. The pragma is now `^0.8.27`, built with 0.8.33: since 0.8.22 the compiler removes the overflow check of such a counter, so `unchecked { ++i }` would buy nothing and is **not** recommended. Parameters are `calldata`; iteration is bounded by `MAX_BATCH_SIZE` (see H-1 for why the bound that matters in practice is the gas cap).

## B. Storage reads

### B-1. Nothing to change

No slot is read twice in one call; each setter writes the record and its `has*` flag once. No external call separates storage accesses.

## C. Events

### C-1. Each event had two emit sites — ✅ fixed

Before: `emit DebtSet` appeared in `setDebt` and in the `setDebtBatch` loop, `emit CreditEventsSet` in `setCreditEvents` and in the `setCreditEventsBatch` loop, each preceded by its own zero-address check and storage writes. "Every write emits" held by convention.

Now: `_setDebt` (`src/DebtEngineBase.sol:145`) and `_setCreditEvents` (`:156`) own validation, write, flag and event; the four public setters call them. `grep -rn 'emit DebtSet\|emit CreditEventsSet' src` returns one site each.

Measured (`forge snapshot --diff`, same test files before and after):

| Path | Δ gas |
|---|---|
| `setDebt` / `setCreditEvents` (single) | +34 (one internal call) |
| `setDebtBatch` / `setCreditEventsBatch`, 2 entries | −1,346 / −1,354 |
| Deployment (`testDeploy`) | −110,569 (AccessControl), −110,555 (Ownable) |
| Runtime size | −551 bytes on both contracts |

Verified by M2, M3 and M7 below (removing the flag, the zero check or the emit from the helper fails 8, 4 and 6 tests).

### C-2. Events carry only the address — ⬜ keep

`DebtSet(address indexed smartContract)` does not carry the record. Putting `DebtInformation` (eleven strings and three integers) in the event would cost several thousand gas per write for data an indexer can read with `debt(address)` at the block of the event. Keep.

### C-3. Forwarder configured without an event — ⬜ keep

`ERC2771Context(forwarderIrrevocable)` sets an immutable; ERC-2771 defines no event, and the value is readable through `trustedForwarder()` / `isTrustedForwarder()`. The admin and owner are evented by OpenZeppelin (`RoleGranted`, `OwnershipTransferred`, tested). Keep.

## D. Duplication

### D-1. Write logic written four times — ✅ fixed

See C-1. The two batch functions still repeat their two `require` lines (length match, size cap); two lines each, not worth a helper.

### D-2. ERC-2771 overrides duplicated — ⬜ keep

`_msgSender`, `_msgData` and `_contextSuffixLength` are identical in `DebtEngineAccessControl` (`:59`–`:69`) and `DebtEngineOwnable` (`:42`–`:52`): 9 code lines each. Probe: a shared `abstract contract DebtEngineERC2771 is DebtEngineBase, ERC2771Context` holding the overrides, inherited by both variants, fails with **`Error (6480)` "Derived contract must override function `_msgSender`"** (and `_msgData`, `_contextSuffixLength`), because `AccessControl` and `Ownable` also inherit `Context`. Solidity requires the most-derived contract to name every base, so the duplication cannot be removed. Keep.

## E. `virtual` / override convention

### E-1. Inconsistent `virtual` — ✅ fixed

Before: the authorization hooks, `version()` and `hasRole` were `virtual`; `debt`, `creditEvents`, `hasDebt`, `hasCreditEvents`, the four setters and the three context overrides in each deployment contract were not. A derived deployment could not, for example, add a check to `setDebtBatch`. Now all are `virtual`; the convention is recorded in `CLAUDE.md` / `AGENTS.md`.

- Cost: `forge snapshot --diff` shows **0** changed entries, `forge build --sizes` identical.
- Guard: `test/DebtEngineHarness.t.sol` overrides `setDebt` and `hasDebt`, so removing `virtual` breaks the build, and `testOverridesOfPublicFunctionsAreReached` asserts the overrides are actually called.

## F. ERC / specification conformance

### F.1 Inventory

| Standard | Status | How the code claims it | Spec text read | Result |
|---|---|---|---|---|
| CMTAT `IDebtEngine` (`ICMTATDebt` + `ICMTATCreditEvents`) | project interface, CMTAT v3.0.0 | `DebtEngineBase is IDebtEngine` | `lib/CMTAT` v3.0.0 | conforms; real `CMTATStandaloneDebt` reads both records in tests |
| ERC-2771 | Final | `ERC2771Context` (OpenZeppelin 5.5.0) in both deployments | `ethereum/ERCs` `erc-2771.md` | conforms: `isTrustedForwarder` exposed and non-reverting; sender taken from the last 20 bytes only for the trusted forwarder (now tested) |
| ERC-173 | Final | `Ownable2Step` in `DebtEngineOwnable` | `ethereum/ERCs` `erc-173.md` | `owner()`, `transferOwnership`, `OwnershipTransferred` (also at deployment, tested); SHOULD-implement ERC-165 was missing → F-1; zero-address renounce deviates → F-3 |
| ERC-165 | Final | `AccessControlEnumerable` (RBAC); now `ERC165` (Ownable) | OpenZeppelin 5.5.0 | RBAC advertises `IAccessControlEnumerable`, `IAccessControl`, `IERC165`; Ownable advertises ERC-173 and ERC-165; `0xffffffff` false (tested) |
| ERC-3643 `version()` | Final (ERC-3643) | `VersionModule.version()` | CMTAT `IERC3643Base` | same signature; not advertised (DebtEngine is not a token) |

### F-1. ERC-173 not advertised through ERC-165 — ✅ fixed

ERC-173: "Contracts should also implement ERC165 for the ERC-173 interface" (`0x7f5828d0`). `DebtEngineOwnable` had no `supportsInterface`. Added `ERC165` and `supportsInterface` (`src/deployment/DebtEngineOwnable.sol:28`), +113 runtime bytes. `testSupportsInterface` pins `type(IERC173).interfaceId == 0x7f5828d0` from a test-local declaration of the standard; mutant M4 (drop the id) fails it.

### F-2. `IDebtEngine` id is `0x00000000` — ⬜ keep

`IDebtEngine` declares no function itself, so `type(IDebtEngine).interfaceId` is `0x00000000`; advertising it would need a flattened id. CMTAT's `setDebtEngine` performs no ERC-165 check, so there is no consumer. Keep.

### F-3. `transferOwnership(address(0))` does not renounce — ✅ documented

ERC-173 specifies renouncing with `transferOwnership(address(0))`. Under OpenZeppelin `Ownable2Step` it only sets `pendingOwner` to zero (cancelling a pending transfer); renouncing is `renounceOwnership`. Documented in the README; `testTransferOwnershipToZeroCancelsPendingTransfer` pins the behaviour.

### F.2 Custom features vs standards

Ownership and roles use OpenZeppelin (ERC-173, `AccessControlEnumerable`); the version getter matches ERC-3643 `version()`; meta-transactions use ERC-2771. Batch setters are custom rather than `Multicall`: keep, because they enforce the size cap and length match in one place. Nothing to adopt.

## G. Code / documentation mismatch

### G-1. Minimum compiler — ✅ fixed (correction of M-1)

M-1 switched guards to `require(condition, CustomError())`. On the legacy pipeline this needs solc 0.8.27: building with `--use 0.8.26` fails with "Require with a custom error is only available using the via-ir pipeline", 0.8.27 compiles. The sources still said `pragma ^0.8.20` and the README "Solidity 0.8.20+". Raised the pragma to `^0.8.27` in `src/` and `test/`, and updated the README and agent guide. Recorded here because the review introduced the mismatch and caught it before finishing.

### G-2. README function table incomplete — ✅ fixed

Added `MAX_BATCH_SIZE()`, `version()`, `supportsInterface(bytes4)`, the `virtual` / single-write-path note and the batch-size caveat (H-1).

### G-3. Agent guide stale — ✅ fixed

`CLAUDE.md` said "function modifier order `internal view override`", contradicted by the hooks (`internal view virtual override onlyOwner`). Replaced with the full attribute order and the `virtual`, `require` and braces conventions. Tool-report paths now point to `doc/tools/v0.3.0/`; the removed draft reviews are no longer listed. `AGENTS.md` re-synced.

### G-4. Reference scan and NatSpec length — ⬜ nothing found

The production-source scan for documentation paths, test names and review IDs returns nothing. NatSpec blocks in `src/` after the review: 22 blocks, median 3.5 lines, longest 10 (`hasRole`, which documents the implicit-admin behaviour). No source comment cites an AI-assisted report, so `CLAUDE_ANALYSIS_SUMMARY.md` is not needed.

## H. Weird behaviour

### H-1. `MAX_BATCH_SIZE` is not the limit that binds — ✅ documented, value open

EIP-7825 (Final, part of Fusaka) caps a transaction at 16,777,216 gas. Measured in the suite (AccessControl variant): one realistic debt record costs about 400k gas (`setDebt` 458,284 gas; a second record in `setDebtBatch` adds 401,580), and `testSetCreditEventsBatchAtMaxSize` (500 short records) costs 35,655,870 gas, about 71k per record. Even 500 *empty* debt records cost 36.4M gas. So on mainnet a batch holds roughly 40 debt records or 230 credit-events records; the cap of 500 can never be reached there. Not a vulnerability (an oversized batch reverts out of gas, nothing is written). Documented in the NatSpec of `MAX_BATCH_SIZE` (`src/DebtEngineBase.sol:21`–`27`) and the README. Whether to lower the value is in *Outstanding*.

### H-2. Records cannot be removed — ⬜ decide (U-1)

Once set, `hasDebt` / `hasCreditEvents` stay `true`; a record can only be overwritten. See U-1.

### H-3. Renouncing freezes the registry — ⬜ keep

`renounceOwnership` (Ownable variant) or renouncing `DEFAULT_ADMIN_ROLE` with no other manager leaves every record permanently frozen. For a registry, freezing can be intended (immutable records); it is OpenZeppelin's behaviour and is documented in the README.

### H-4. Caller-based getters through a forwarder — ⬜ keep

`debt()` returns the record of `_msgSender()`; through the trusted forwarder anyone can make it answer for any token address (tested in `testDebtForCallerThroughTrustedForwarder`). Harmless: `debt(address)` already exposes every record.

## I. Interface granularity

### I-1. Nothing found

CMTAT's `DebtEngineModule` calls `debt()` and `creditEvents()`; `IDebtEngine` requires exactly those two functions (one from `ICMTATDebt`, one from `ICMTATCreditEvents`). No ERC-165 guard.

## J. Modularity

### J-1. `view` hooks and OpenZeppelin `AccessManaged` — ⬜ keep

Probe (scratch copy, deleted): a third deployment `DebtEngineAccessManaged is DebtEngineBase, AccessManaged` overriding the hooks with `restricted` fails with **`Error (8961)` "Function cannot be declared as view because this expression (potentially) modifies the state"**: `restricted` may consume a scheduled operation. An override cannot relax `view`, so the only way to use `restricted` would be dropping `view` from the base hooks, losing the compiler guarantee that authorization never writes state. A view-only alternative **compiles**:

```solidity
function _authorizeSetDebt() internal view virtual override {
    (bool immediate,) = AuthorityUtils.canCallWithDelay(authority(), _msgSender(), address(this), msg.sig);
    require(immediate, IAccessManaged.AccessManagedUnauthorized(_msgSender()));
}
```

It supports immediate permissions only (no scheduled, delayed operations). Keep `view`; use this form if an AccessManager variant is ever needed.

### J-2. Legibility — ⬜ keep

```
src/DebtEngineBase.sol                      abstract contract DebtEngineBase
src/DebtEngineInvariantStorage.sol          abstract contract DebtEngineInvariantStorage
src/deployment/DebtEngineAccessControl.sol  contract DebtEngineAccessControl
src/deployment/DebtEngineOwnable.sol        contract DebtEngineOwnable
src/modules/VersionModule.sol               abstract contract VersionModule
```

Directories match contents (`deployment/` holds the only deployable contracts). `DebtEngineInvariantStorage` holds only errors, but the name follows the CMTAT ecosystem convention, so keep. Embedding the engine in a token is not a goal (it is an external engine by design), so no downstream-embedding probe was needed.

## K. Tests

### K.1 Correctness

- Every guard has a negative test with the exact selector and arguments: `SmartContractWithAddressZeroNotAllowed` (4 paths), `InvalidInputLength` (both directions, both batches), `BatchSizeTooLarge` (both batches, new), `AdminWithAddressZeroNotAllowed`, `OwnableInvalidOwner`, both hooks in both variants, role separation, pending-owner acceptance.
- Before the review, `BatchSizeTooLarge` had **no test** and the length check was tested only with fewer addresses than records.
- Low-level forwarder calls use `vm.expectRevert` with the specific unauthorized-account error and the relayed address.

Mutants, each run in a throwaway copy of the repository (working tree untouched):

| # | Mutation | Result |
|---|---|---|
| H1–H3 | Remove the modifier from one hook (AC debt, AC credit events, Ownable debt) | killed (4 failures each) |
| M1 | First batch cap `<=` → `<` | killed (2) |
| M2 | Drop the `has*` flag in `_setDebt` | killed (8) |
| M3 | Drop the zero check in `_setCreditEvents` | killed (4) |
| M4 | Drop the ERC-173 id from `supportsInterface` | killed (1) |
| M5 | AC `_msgSender` returns `msg.sender` (ignore forwarder) | killed (3) |
| M6 | Drop the implicit-admin shortcut in `hasRole` | killed (32) |
| M7 | Drop `emit DebtSet` | killed (6) |
| M8 | Debt batch length `==` → `>=` | **survived**, then killed (2) by the new "more addresses than records" tests |
| M9 | Credit batch length `==` → `>=` | killed (2) after the same tests |
| M10 | Remove the debt batch size guard | killed (`testCannotSetDebtBatchAboveMaxSize`) |

### K.2 Coverage (`forge coverage`, tests excluded from the report)

| Contract | Lines | Branches | Funcs | Uncovered | Verdict |
|---|---|---|---|---|---|
| `DebtEngineBase` | 100% (42/42) | 100% (12/12) | 100% (15/15) | — | — |
| `DebtEngineAccessControl` | 86.67% (13/15) | 100% (3/3) | 85.71% (6/7) | `_msgData` | acceptable: required override, nothing in OpenZeppelin `AccessControl` calls it |
| `DebtEngineOwnable` | 80% (8/10) | 100% (0/0) | 83.33% (5/6) | `_msgData` | acceptable: same reason |
| `VersionModule` | 100% | 100% | 100% | — | — |

Before the review: `DebtEngineBase` 92.31% lines, 75% branches (both `BatchSizeTooLarge` guards and the base `_msgSender` uncovered). The HTML report in `doc/coverage/` was regenerated.

### K.3 Edge cases

| Family | Cases missing before | Test written |
|---|---|---|
| Boundaries | batch of exactly `MAX_BATCH_SIZE`, `MAX_BATCH_SIZE + 1`, empty batch | `testSet*BatchAtMaxSize`, `testCannotSet*BatchAboveMaxSize`, `testEmptyBatchesAreNoOps` |
| Duplicates and order | same address twice in one batch | `testDuplicateAddressInDebtBatchLastWriteWins` (last write wins, two events) |
| State transitions | overwriting a record; ownership transfer to zero | `testSetDebtOverwritesPreviousRecord`, `testTransferOwnershipToZeroCancelsPendingTransfer` |
| Authorization | relayed call through the trusted forwarder (authorized, unauthorized, spoofed by a non-forwarder) | `testSetDebtThroughTrustedForwarder`, `testForwarderCannotRelayUnauthorizedSigner`, `testUntrustedCallerCannotSpoofSender` |
| Arithmetic / values | arbitrary record values | `testFuzz_SetDebtRoundTrip`, `testFuzz_SetCreditEventsRoundTrip` (256 runs each, both variants) |
| Events | deployment `OwnershipTransferred`; no event on empty batch | `testOwnershipTransferredEmittedAtDeployment`, `testEmptyBatchesAreNoOps` |

Fuzzed: write-then-read for both record types. Not invariant-tested: no conserved quantity beyond "a record equals the last write", which the fuzz tests cover. Reentrancy: no external calls in the engine.

## L. Control-flow bodies in braces

### L-1. None found

The brace scan on `src/` and `test/` returns nothing.

## M. Guards

### M-1. `if`/`revert` → `require(cond, Error())` — ✅ fixed

Nine guards converted (`src/DebtEngineBase.sol:113`, `:114`, `:129`, `:130`, `:146`, `:157`; `src/deployment/DebtEngineAccessControl.sol:19`; the two single setters now go through the helpers). No exception was needed: every error argument is a calldata length or a constant. Measured: batch calls +13 gas (`BatchSizeTooLarge(smartContracts.length, MAX_BATCH_SIZE)` is built on the success path), deployment about +1,200 gas, runtime +6 bytes, before C-1. Revert data is unchanged, so every existing `expectRevert` passed unchanged. Side effect: minimum compiler 0.8.27 (G-1).

## U. User experience

Actors: the deployer (admin or owner, forwarder), the debt manager and credit-events manager (or the owner), the CMTAT token (reads its own record), integrators and indexers (read any record), relayers (ERC-2771).

| ID | Actor | Journey step | What they must do today | Proposed addition | Verdict |
|---|---|---|---|---|---|
| U-1 | Debt / credit-events manager | Retire a token or correct a record set by mistake | Overwrite with an empty struct; `hasDebt` still says `true` | `clearDebt` / `clearCreditEvents` | ✅ done |
| U-2 | Indexer | List every token that has a record | Replay `DebtSet` / `CreditEventsSet` from deployment | On-chain enumeration | leave |
| U-3 | Manager | Size a batch that fits in one transaction | Trial and error against the gas cap | Documentation (H-1) | ✅ done |

### U-1. Clearing a record

1. **Journey:** a manager retires a token, or removes a record written to the wrong address.
2. **Today:** `setDebt(token, emptyStruct)`; `debt(token)` returns zeros but `hasDebt(token)` stays `true`, so an integrator using `hasDebt` to mean "has a debt record" reads a cleared token as configured.
3. **Change, as code (Proposed, compiled in a scratch copy, then deleted):**

   ```solidity
   event DebtCleared(address indexed smartContract);
   event CreditEventsCleared(address indexed smartContract);

   /// @notice Deletes the debt record of `smartContract_`; `hasDebt` returns false afterwards.
   function clearDebt(address smartContract_) external virtual onlyDebtManager {
       delete _debts[smartContract_];
       delete _debtSet[smartContract_];
       emit DebtCleared(smartContract_);
   }

   /// @notice Deletes the credit events of `smartContract_`; `hasCreditEvents` returns false afterwards.
   function clearCreditEvents(address smartContract_) external virtual onlyCreditEventsManager {
       delete _creditEvents[smartContract_];
       delete _creditEventsSet[smartContract_];
       emit CreditEventsCleared(smartContract_);
   }
   ```

4. **How to adopt:** add to `DebtEngineBase` (both variants inherit it; the existing hooks gate it), update the README function table and the capability table.
5. **Limits and interactions:** a CMTAT token pointing at the engine then reads an empty record, the same as before it was set; no storage-layout change (no new state); new ABI entries and events.
6. **Cost, measured:** +599 runtime bytes (`DebtEngineAccessControl` 8,573 → 9,172), +565 (`DebtEngineOwnable`), `forge build --sizes`; both far below EIP-170.
7. **Test to add:** set → clear → `hasDebt == false`, `debt()` equals the zero struct, event emitted; unauthorized caller rejected in both variants.
8. **Verdict: decide.** It changes what `hasDebt` means ("currently set" instead of "ever set"), which is a product decision.
9. **Decision: adopted.** Implemented in `DebtEngineBase` as proposed, with internal delete paths `_clearDebt` / `_clearCreditEvents`; `hasDebt` / `hasCreditEvents` now mean "currently set". Measured cost: +617 runtime bytes (`DebtEngineAccessControl` 8,573 → 9,190), +587 (`DebtEngineOwnable` 7,107 → 7,694). Tests added in the shared suite (both variants) and RBAC role-separation tests. Linked from `doc/tools/CLAUDE_ANALYSIS_SUMMARY.md` S-1.

### U-2. Enumerating the tokens with a record

1. **Journey:** an indexer or dashboard lists every token the engine serves.
2. **Today:** replays `DebtSet` / `CreditEventsSet` since deployment and de-duplicates.
3. **Change:** an `EnumerableSet.AddressSet` updated in `_setDebt` / `_setCreditEvents`, with `tokens()` / `tokenCount()` views (not implemented, not compiled).
4. **How to adopt:** update the set in the single write paths (C-1 makes that a two-line change).
5. **Limits:** one extra storage write (about 20k–45k gas) on the first record of each token; unbounded return array for `tokens()`.
6. **Cost:** not measured, as the verdict is leave.
7. **Test:** set count equals the number of distinct tokens written, fuzzed.
8. **Verdict: leave.** Events plus `hasDebt` answer the question off-chain, and the engine serves a small number of issuer tokens.

## Static analysis (Aderyn, regenerated)

`doc/tools/v0.3.0/aderyn-report.md`: 0 High, 7 Low, all by design: L-1 centralization (authorized roles are the point of the engine), L-2 floating pragma (`^0.8.27` lets integrators compile with newer solc; the project pins 0.8.33), L-3 PUSH0 (`prague` target; set `evm_version` for chains without it), L-4 empty blocks (the hook idiom: the check is the modifier), L-5 / L-6 `require` and storage writes in loops (bounded batches), L-7 unchecked return of `_grantRole` in the constructor (always `true` on a fresh contract).

## Corrections during the review

- **G-1 was introduced by M-1.** Converting to `require` with custom errors silently raised the minimum compiler to 0.8.27 while the pragma still said `^0.8.20`; caught by the documentation pass and fixed.
- **Cumulative gas diffs are not comparable.** Comparing the final snapshot with the initial one shows `setDebt` +647 gas, which contradicts the per-step +34. The difference comes from the 35 new test functions changing the test contracts' selector dispatch, which `forge snapshot` charges to the test. The per-step figures above were each measured with unchanged test files and are the valid ones.

## Review completeness

**Setup**
- [x] Mode: patching, chosen by the user; stated in the header.
- [x] Conventions read (`CLAUDE.md` / `AGENTS.md`, `CONTRIBUTING.md`); solc 0.8.33, optimizer 200, no `via_ir`.
- [x] Baseline: build and tests green, 69 tests.

**Checks**
- [x] A — compiler checked before loop advice; `calldata`; bounded iteration.
- [x] B — nothing to cache.
- [x] C — emit sites counted; `_setX` helpers implemented and measured.
- [x] D — duplication found; the reason D-2 cannot be shared proven by compile (`6480`).
- [x] E — convention made explicit in the agent guide; harness test.
- [x] F.1 — inventory table; ERC-173 and ERC-2771 read from the spec text (`ethereum/ERCs`); ERC-165 ids pinned in tests.
- [x] F.2 — compared; nothing to adopt.
- [x] G — doc claims grepped; NatSpec distribution measured; reference scan empty; rule already in the agent guide.
- [x] H — per-contract questions asked; H-1 measured against EIP-7825.
- [x] I — functions called vs required counted.
- [x] J — listing run; AccessManaged probe compiled and graded (`8961`); scratch files outside the repository.
- [x] K.1 — every guard has a negative test; 13 mutants, 1 survivor killed by new tests.
- [x] K.2 — `forge coverage` run; uncovered items have verdicts.
- [x] K.3 — families walked; fuzzed properties stated.
- [x] L — brace scan empty.
- [x] M — 9 guards converted, measured.
- [x] U — actors and journeys; U-1 code compiled and sized; U-2 labelled not compiled.

**Measurement and changes**
- [x] Gas figures from `forge snapshot --diff` per step, with unchanged test files; probe and mutation copies kept outside the repository.
- [x] Fixes seen to fail when reverted (mutants M2–M10, harness compile for E-1).
- [x] Storage layout: no state variable added, removed or reordered (only internal functions, `virtual`, guards and `supportsInterface`); ABI additions: `supportsInterface` on `DebtEngineOwnable` only.
- [x] End: `forge fmt --check`, `forge build`, `forge test` green (104 tests = 69 + 35 added); sizes far below EIP-170.
- [x] Report-only checks: N/A (patching mode).

**Report**
- [x] Header complete, vulnerability statement included.
- [x] File:line references re-checked against the final code.
- [x] Corrections kept in place.
- [x] Disposition rows counted (29).
- [x] Outstanding lists the open decisions and the stale Slither report.
- [x] K and U tables present.

**Finally**
- [x] Changelog and agent guides updated (`CLAUDE.md` = `AGENTS.md`).
- [x] No source comment cites this report.
- [x] Commit message offered.
