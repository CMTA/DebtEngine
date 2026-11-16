# DebtEngine v0.3.0 — Threat Model

## Run options

| Option | Value | Source |
|---|---|---|
| `--mode` | `full` (tests written to `test/`) | asked |
| `--scope` | `all` — `src/DebtEngineBase.sol`, `src/DebtEngineInvariantStorage.sol`, `src/modules/VersionModule.sol`, `src/deployment/DebtEngineAccessControl.sol`, `src/deployment/DebtEngineOwnable.sol` (no scope file; `lib/`, `test/` out of scope) | asked (`auto` → `all`) |
| `--out` | `AUDIT/` | asked |
| `--judge` | `on` | asked |

Audited commit: `705208b` (branch `dev`). Toolchain: solc 0.8.33, optimizer 200 runs, legacy pipeline (no `via_ir`), `evm_version = prague`, Foundry 1.5.0. Dependencies: CMTAT v3.0.0 (`69eecc9`), OpenZeppelin Contracts v5.5.0 (`fcbae539`), forge-std v1.13.0.

## Claude Skills Used

| Skill | Purpose / Contribution |
|---|---|
| `sc-analyse-and-test` | Entrypoint: run options, ecosystem detection, dispatch |
| `sc-analyse-and-test-solidity` | Workflow and deliverable structure |
| `audit-access-control` | Role inventory, renounce / deployer-retention questions, selector-keyed completeness (§J) → AC-1..AC-6 |
| `cmtat-audit` | CMTA's down-weighting of role-gated issues (trusted admin); no prior finding on the implicit-admin `hasRole` override |
| `cmtat` | CMTAT `DebtEngineModule` delegation (`debt()` / `creditEvents()` forwarded to the engine when set) → INT-1, DATA-3 |
| `openzeppelin-v5` | `AccessControl._grantRole` / `_revokeRole` call the virtual `hasRole` → AC-3; `ERC2771Context` sender extraction → MTX-1..3 |
| `erc173-ownership` | Two-step transfer and `transferOwnership(address(0))` semantics → AC-5 |

## Project overview

DebtEngine is an external engine for CMTAT debt tokens. One deployed engine stores a `DebtInformation` record and a `CreditEvents` record per token address. A CMTAT token configured with `setDebtEngine(engine)` answers its own `debt()` / `creditEvents()` by calling the engine, which returns the record stored under `_msgSender()` (the token). Records are written, overwritten and deleted by privileged managers only. The engine holds no funds and makes no external calls.

Two deployment contracts share the abstract `DebtEngineBase`:

- `DebtEngineAccessControl` — OpenZeppelin `AccessControlEnumerable`; `DEBT_MANAGER_ROLE`, `CREDIT_EVENTS_MANAGER_ROLE`; `DEFAULT_ADMIN_ROLE` implicitly holds every role (`hasRole` override).
- `DebtEngineOwnable` — OpenZeppelin `Ownable2Step`; the owner does everything.

Both inherit `ERC2771Context` with an immutable trusted forwarder (`address(0)` disables it).

## Trust model and actors

| Actor | Trust | Capabilities |
|---|---|---|
| `DEFAULT_ADMIN_ROLE` holder (RBAC) | Fully trusted | Every role implicitly; grant / revoke every role; renounce |
| `DEBT_MANAGER_ROLE` | Trusted for debt data | `setDebt`, `setDebtBatch`, `clearDebt` |
| `CREDIT_EVENTS_MANAGER_ROLE` | Trusted for credit data | `setCreditEvents`, `setCreditEventsBatch`, `clearCreditEvents` |
| Owner (Ownable) | Fully trusted | All six writers; two-step transfer; renounce |
| Trusted forwarder | Fully trusted, immutable | Can make the engine see any `_msgSender()` it appends |
| CMTAT token | Untrusted caller, reads only | `debt()` / `creditEvents()` for itself |
| Anyone | Untrusted | All views (`debt(address)`, `hasDebt`, …) |

## Reachable attack surface (manual call graph)

Slither could not run (`ModuleNotFoundError: No module named 'slither'`), so the call graph below was traced by hand; `AUDIT/slither-graph/` is empty.

```
External entry points                    Guard                         Internal path
setDebt(addr, info)            ──► onlyDebtManager ─► _authorizeSetDebt ─► _setDebt ─► _debts, _debtSet, DebtSet
setDebtBatch(addrs, infos)     ──► onlyDebtManager ─► length/size require ─► loop _setDebt
clearDebt(addr)                ──► onlyDebtManager ─► _clearDebt ─► delete, DebtCleared
setCreditEvents / Batch / clearCreditEvents ──► onlyCreditEventsManager ─► _setCreditEvents / _clearCreditEvents
debt() / creditEvents()        ──► none ─► _msgSender() (ERC-2771) ─► debt(addr) / creditEvents(addr)
debt(addr), creditEvents(addr), hasDebt, hasCreditEvents, version, MAX_BATCH_SIZE ──► none (views)
RBAC: grantRole / revokeRole   ──► onlyRole(getRoleAdmin(role)) = DEFAULT_ADMIN (via overridden hasRole) ─► _grantRole / _revokeRole (call hasRole)
RBAC: renounceRole(role, self) ──► callerConfirmation == _msgSender() ─► _revokeRole (calls hasRole)
Ownable: transferOwnership / acceptOwnership / renounceOwnership ──► onlyOwner / pendingOwner
```

Every state-changing entry point of `DebtEngineBase` passes through one of the two hooks; no privileged function is reachable without them.

## Attack surface analysis

| ID | Threat | Severity (initial) | Component |
|---|---|---|---|
| AC-1 | A write function reachable without its authorization hook (selector completeness across set / batch / clear, both variants) | High | `DebtEngineBase.sol:94-157` |
| AC-2 | Role separation bypass: debt manager writes credit events or vice versa | Medium | `DebtEngineAccessControl.sol:25-27` |
| AC-3 | Implicit-admin `hasRole` override changes `_grantRole` / `_revokeRole` / `renounceRole` bookkeeping for admins (no-op grants, misleading revocations) | Low | `DebtEngineAccessControl.sol:41-53`, OZ `AccessControl.sol:181-206` |
| AC-4 | Last `DEFAULT_ADMIN_ROLE` holder renounces: roles can never be granted again | Low | OZ `AccessControl.renounceRole` |
| AC-5 | Ownership lost through a mistyped transfer or renounce | Low | `DebtEngineOwnable.sol` (Ownable2Step) |
| AC-6 | Compromised admin / owner / manager key rewrites or deletes records | High | trusted actor |
| MTX-1 | Non-forwarder spoofs `_msgSender()` by appending an address | High | `ERC2771Context._msgSender` |
| MTX-2 | Trusted forwarder compromised or able to relay arbitrary calls impersonates the admin; forwarder is immutable | Medium | constructors |
| MTX-3 | `forwarder = address(0)` makes some sender trusted | Low | `ERC2771Context` |
| DATA-1 | Record written for `address(0)` | Low | `_setDebt`, `_setCreditEvents` |
| DATA-2 | `clearDebt` / `clearCreditEvents` accept `address(0)` and unset records, emitting events for nothing | Info | `_clearDebt`, `_clearCreditEvents` |
| DATA-3 | Once a token points to the engine, the engine's record (or its absence) shadows the token's own `DebtModule` data | Low | CMTAT `DebtEngineModule.sol:49-71` |
| DATA-4 | Duplicate addresses in a batch: last write wins silently | Info | batch setters |
| DOS-1 | Batches above the per-transaction gas cap (EIP-7825) always revert | Info | `MAX_BATCH_SIZE` |
| DOS-2 | Unbounded strings make a write too expensive | Info | trusted writer |
| INT-1 | CMTAT reads the record of `msg.sender`; a third party reads another token's record | Info | `debt()`, `debt(address)` |
| INT-2 | `IDebtEngine` interface mismatch with CMTAT v3.0.0 | Medium | `DebtEngineBase` |
| STD-1 | ERC-165 advertises an interface not implemented, or misses one | Low | both `supportsInterface` |
| UPG-1 | Initializer front-running / storage collision | — | N/A: not upgradeable, constructor-only |
| REE-1 | Reentrancy | — | N/A: no external calls in the engine |

## Critical findings summary (pre-test)

No Critical or High issue is expected: the engine holds no value and every write is gated. The leads to confirm with tests are AC-3 (role bookkeeping with the implicit admin), DATA-3 (shadowing of token-local data) and the trust placed in the immutable forwarder (MTX-2).

## Data flow

```
Issuer ops ──setDebt──► DebtEngine[_debts[token]] ◄──debt()── CMTAT token ◄──debt()── holder / integrator
                              ▲                                  │ (engine set → engine answer;
Relayer ──(forwarder + signer suffix)──┘                         │  engine unset → token-local DebtModule)
```

## External dependencies and trust assumptions

| Dependency | Version | Use | Risk |
|---|---|---|---|
| OpenZeppelin `AccessControlEnumerable`, `Ownable2Step`, `ERC2771Context`, `ERC165` | v5.5.0 | Access control, meta-tx, introspection | Audited library; the `hasRole` override changes its internal semantics (AC-3) |
| CMTAT `IDebtEngine`, `ICMTATDebt`, `ICMTATCreditEvents` | v3.0.0 | Interface and structs | Struct layout must match the token's version |
| Trusted forwarder | deployment choice | ERC-2771 | Fully trusted and immutable |

## Invariants

- I-1: only an authorized account (hook passes) can change `_debts`, `_creditEvents`, `_debtSet`, `_creditEventsSet`.
- I-2: `hasDebt(a)` is true iff the last write to `a` was a set (not a clear); same for credit events.
- I-3: `debt(a)` equals the last record set for `a`, or the zero struct after a clear / before any set.
- I-4: no record is ever stored under `address(0)`.
- I-5: a debt manager cannot change credit events and vice versa (RBAC).
- I-6: without the trusted forwarder, `_msgSender() == msg.sender`.

## Threat disposition rule

Every threat ID above receives an explicit outcome in `RESULT.md`: a numbered finding with severity, or `NOT-A-FINDING` with a reason.
