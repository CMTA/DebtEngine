# DebtEngine — Agent Guide

> **Note — keep in sync:** `AGENTS.md` and `CLAUDE.md` must always be **identical**. Any edit to one must be applied verbatim to the other.

> **Note — commit messages:** After each group of modifications or each feature added, always provide a **one-line GitHub commit message** (Conventional-Commits style, e.g. `feat: ...`, `fix: ...`, `docs: ...`, `test: ...`).
>
> **Never put `!` in a commit message** — not as the breaking-change marker (`feat!: ...`), not anywhere else. In an interactive bash, `!` inside double quotes triggers history expansion, so `git commit -m "feat!: ..."` aborts with `bash: !: unrecognized history modifier`. Signal a breaking change with an uppercase `BREAKING CHANGE:` line in the commit body instead, and keep the subject line free of `!`.
>
> **Always sign commits** — every commit must be signed with `-S`, both the commands you suggest to the user (`git commit -S -m "..."`) and any commit you make yourself. If signing fails (no key configured, agent locked, `gpg failed to sign the data`), stop and report it; never fall back to an unsigned commit or to `--no-gpg-sign`.

> **Note — no tool names in the changelog:** never name an assistant tool, skill or slash command in `CHANGELOG.md`. The changelog records what changed in *this project*, for readers who have no idea what tooling produced it. A line ending "the `<some-skill>` skill gained the corresponding check" documents the author's toolbox rather than the release, and it rots independently of the repository — the tool can be renamed or deleted, leaving a dangling reference to something the reader could never have seen. Describe the change and its effect; if the tooling matters, record it in the audit or analysis report instead.
>
> This is about **tool identities, not the word "Claude"**: files committed to the repository — `CLAUDE.md`, `AGENTS.md`, `doc/tools/<version>/CLAUDE_ANALYSIS.md` — are cited freely, because a reader can open them.

> **Note — do not hard-wrap prose in `CHANGELOG.md`:** one line per bullet or paragraph, and let the editor soft-wrap. Markdown collapses a single newline into a space, so a hard-wrapped bullet renders identically — the cost is invisible in the published changelog and paid entirely in the repository. Changing one word reflows every following line, so a one-word correction arrives as a multi-line diff in which a reviewer cannot see what actually changed; and because the wrap column depends on whoever wrote the entry, the file drifts into a mix of styles that reads as damage. Keep the line structure only where it is semantic: fenced code blocks, tables and blockquotes.

> **Note — never break the code in place to test a test:** when you need to verify that a test actually catches a defect — mutation testing: delete an assert, flip a condition, drop a delivery — do it in a **throwaway copy of the repository**, never in the working tree.
>
> Editing source forces a rebuild, and if that run is interrupted — an OOM kill, a timeout, a cancelled command — the restored source and the stale build output **disagree**: `git status` reports a clean tree while `out/` and `cache/` hold artifacts built from the mutated code. Nothing surfaces that state, and restoring the source does not restore the build. It has already happened once in a sibling project, leaving compiled artifacts missing a safety check one step before a release tag.
>
> The procedure: `git worktree add /tmp/mut HEAD --detach`, copy across any uncommitted test files the mutation needs (a worktree is made from the last commit, so new tests are absent), mutate and run there, then `git worktree remove /tmp/mut`. If a mutation ever does run in the working tree, rebuild and **prove** recovery against a recorded build fingerprint rather than assuming it.

> **Note — long changelog entries get sub-bullets:** past roughly three sentences, a bullet stops being scannable — the defect, its blast radius, the fix, the precedent and the caveat all run together, so a reader looking for any one of them has to parse all five. Lead with one sentence naming *what changed*, then one sub-bullet per distinct claim: impact, fix, behaviour-change warning, cost, migration note. A useful trigger is length — compare against the file's own median bullet and split anything several times longer, since that length almost always means several claims in one paragraph. Sub-bullets follow the same no-hard-wrap rule: one line each.

> **Note — never reference documentation, tests or agent reports from production code:** NatSpec and comments in the production sources (`src/`) must not cite a documentation page (`doc/`, `*.md`, `README`), a test file or test name (`test/`, `*.t.sol`, `testFoo`, `invariant_...`), a mock file, a planning ID, or a report produced by an AI assistant (`doc/tools/<version>/CLAUDE_ANALYSIS.md`, `FEEDBACK.md`, `CLAUDE_ANALYSIS*.md`, `RESULT.md`, `THREAT_MODEL.md` or any other agent-written review, including its finding IDs), by path or by bare filename.
>
> Documentation paths move, tests are renamed, and agent reports are regenerated with IDs that restart at `-1` each release (so `CLAUDE_ANALYSIS.md D-1` names a different finding in every version). A stale pointer inside a deployed, verified contract cannot be fixed afterwards, and a reader on a block explorer has the source and nothing else. **Write the substance into the comment instead**: the conclusion and the warning, so the reader gets the whole point without the file. If the explanation is too long for NatSpec, the comment states the conclusion and the documentation carries the derivation, with no cross-reference in the code.
>
> - **Exception: tests.** `test/` is never deployed and exists to serve the suite, so a pointer to the page explaining what a test stands in for is useful and costs nothing.
> - **Exception: official audits by an audit company**, cited by **bare filename and finding ID** (e.g. `Halborn-2024-Q3.pdf` H-03, `OpenZeppelin-audit.md` M-2). An external audit is an immutable historical record, the bare filename survives the file being moved, and the ID gives a reviewer context a comment cannot restate. Never cite it by path.
> - **The audit exception does not cover AI-assisted reviews.** A report written with an AI assistant is a working document that is rewritten as the code changes, not a record; treat it like any other documentation. Agent guides (`CLAUDE.md` / `AGENTS.md`), changelogs and audit overviews may cite these reports freely: they are not deployed.
> - **The link between code and AI findings lives in [`doc/tools/CLAUDE_ANALYSIS_SUMMARY.md`](./doc/tools/CLAUDE_ANALYSIS_SUMMARY.md)**, next to the project's tool reports. Whenever an AI-assisted finding changes production code, or explains why it must not change, add an entry there instead of a citation in the comment: the `file:line` and symbol, the code line, the comment (before and after if a citation was removed), the finding with its **report, release, ID and title** (IDs restart each release), and the change applied. Keep the line numbers current when a symbol moves.

## What this project is

DebtEngine is an external engine for the [CMTAT](https://github.com/CMTA/CMTAT) security token: a single contract stores `debt` (`DebtInformation`) and `credit events` (`CreditEvents`) for many CMTAT token contracts, keyed by token address. It implements CMTAT's `IDebtEngine` interface; a CMTAT debt token calls `debt()` / `creditEvents()` and the engine answers for `_msgSender()`. Unaudited (see README).

## Key concepts

- **Abstract base + deployment variants:** `DebtEngineBase` holds all storage and logic; authorization is delegated to two hooks, `_authorizeSetDebt()` and `_authorizeSetCreditEvents()`, which must revert when the caller is not allowed (used by the `onlyDebtManager` / `onlyCreditEventsManager` modifiers).
- **`DebtEngineAccessControl`** (RBAC, OpenZeppelin `AccessControlEnumerable`): roles `DEBT_MANAGER_ROLE` and `CREDIT_EVENTS_MANAGER_ROLE`; `hasRole` is overridden so `DEFAULT_ADMIN_ROLE` implicitly holds every role (this implicit membership is not listed by `getRoleMember*`). Constructor rejects a zero `admin`.
- **`DebtEngineOwnable`** (OpenZeppelin `Ownable2Step`): the owner is the only writer for both debt and credit events; ownership transfer requires `acceptOwnership` by the new owner.
- **ERC-2771 meta-transactions:** only the deployment contracts inherit `ERC2771Context`; the base defines a virtual `_msgSender()` returning `msg.sender`. The forwarder is set in the constructor and is **immutable**; `address(0)` disables it.
- **Getters:** `debt()` / `creditEvents()` (for the caller), `debt(address)` / `creditEvents(address)`, and `hasDebt(address)` / `hasCreditEvents(address)`, which mean "currently set" (true after a set, false again after a clear) and distinguish "no record" from "set to empty".
- **Setters:** `setDebt`, `setCreditEvents`, `setDebtBatch`, `setCreditEventsBatch`; all writes go through `_setDebt` / `_setCreditEvents` (zero-address check, write, `has*` flag, event) — never write the mappings or emit `DebtSet` / `CreditEventsSet` anywhere else; batches capped by `MAX_BATCH_SIZE = 500` (a ceiling: the mainnet per-transaction gas cap binds first) and require equal array lengths.
- **Clear:** `clearDebt` / `clearCreditEvents` delete a record and its `has*` flag only through `_clearDebt` / `_clearCreditEvents`, which emit `DebtCleared` / `CreditEventsCleared`; gated by the same hooks as the setters; reject `address(0)` like the setters; clearing an unset record succeeds.
- **Errors** live in `DebtEngineInvariantStorage` (abstract).
- **Version:** `version()` comes from `VersionModule`, inherited by `DebtEngineBase` (there is no public `VERSION` getter).
- **Not upgradeable:** plain constructor deployment, no proxy.

## File tree

```
src/
├── DebtEngineBase.sol                    # abstract engine: storage, getters/setters, events, auth hooks
├── DebtEngineInvariantStorage.sol        # abstract: custom errors
├── modules/
│   └── VersionModule.sol                 # abstract: private VERSION constant + version() getter (CMTAT BaseModule pattern)
└── deployment/
    ├── DebtEngineAccessControl.sol       # RBAC variant (AccessControlEnumerable + ERC2771Context)
    └── DebtEngineOwnable.sol             # single-owner variant (Ownable2Step + ERC2771Context)
test/
├── DebtEngineBase.t.sol                  # abstract shared suite (DebtEngineBaseTest), incl. CMTATStandaloneDebt integration
├── DebtEngineAccessControl.t.sol         # role-specific tests for the RBAC variant
├── DebtEngineOwnable.t.sol               # owner-specific tests for the Ownable variant (incl. ERC-165 / ERC-173)
├── DebtEngineHarness.t.sol               # test-only engine: proves public functions stay `virtual`, covers the base `_msgSender()`
├── DebtEngineThreatModel.t.sol           # security-audit tests: PoCs for the CLAUDE_AUDIT.md findings, fuzzed access-control and set/clear model
├── DeployGuideCMTATv3.0.0.t.sol          # runs every step of doc/technical/guides/DEPLOY_DEBT_ENGINE_CMTAT_V3.0.0.md against CMTAT v3.0.0
└── script/DeployScripts.t.sol            # tests for the deployment scripts
script/
├── DeployDebtEngine.s.sol                # deploy either variant (env: ENGINE_VARIANT, ENGINE_ADMIN, FORWARDER, DEBT_MANAGER, CREDIT_EVENTS_MANAGER)
└── ConnectDebtEngine.s.sol               # token side: setDebtEngine (env: TOKEN, DEBT_ENGINE, ALLOW_EMPTY_RECORD); refuses an empty record
```

## Other important files

- `CHANGELOG.md` — release notes, change-type tags and the pre-release checklist.
- `README.md` — data structures, interface, schemas, toolchain commands.
- `foundry.toml` — solc `0.8.33`, optimizer 200 runs, `evm_version = prague`.
- `hardhat.config.js` — Hardhat 2 compilation of `src/` only, same compiler settings as `foundry.toml` (keep them in sync), imports via the Foundry remappings (`@nomicfoundation/hardhat-foundry`); output in `artifacts/` and `cache_hardhat/` (git-ignored).
- `remappings.txt` — `CMTAT/` → `lib/CMTAT/contracts/`, `OZ/` → `lib/openzeppelin-contracts/contracts/`, `@openzeppelin/contracts-upgradeable/`.
- `doc/coverage/` — lcov + HTML coverage report.
- `doc/compilation/v<version>/` — per-release Hardhat and Foundry artifacts and flattened sources of the two deployable contracts (see its README; added for releases, not release candidates).
- `doc/technical/guides/` — deployment guides (`DEPLOY_DEBT_ENGINE_CMTAT_V3.0.0.md`); each step is run by a test, keep the two in sync.
- `doc/tools/AUDIT_OVERVIEW.md` — index of every analysis (static analysis, AI reviews, coverage) with their results.
- `doc/tools/<version>/` — tool reports per release: `slither-report.md` / `aderyn-report.md` with their `*-feedback.md` triage, the AI-assisted code-quality review `CLAUDE_ANALYSIS.md` and the published security audit `CLAUDE_AUDIT.md` (currently `doc/tools/v0.3.0/`).
- `doc/script/` — Surya scripts; output in `doc/surya/` (graph, inheritance, report).
- `doc/tools/v0.3.0/CLAUDE_AUDIT.md` — published security audit of v0.3.0 (findings, invariants, access-control verification, remediation). Its working files (threat model, test plan, raw results) are local drafts in `draft/AUDIT/`, not committed.
- `lib/` — git submodules (do not edit).
- `draft/` — local, git-ignored folder for working notes and scratch files (e.g. `FEEDBACK.md`, `INSTRUCTION.md`). Put drafts there, never at the root; never cite a `draft/` file from a committed file (code, docs, changelog), since readers of the repository cannot open it.

## Dependencies (tested versions)

- Foundry, solc `0.8.33` (sources use `pragma ^0.8.27`, the minimum for `require(bool, CustomError())` on the legacy pipeline)
- OpenZeppelin Contracts — submodule `lib/openzeppelin-contracts` (v5.x, commit `fcbae539`)
- OpenZeppelin Contracts Upgradeable — submodule v5.5.0 (tests, via CMTAT)
- CMTAT — submodule `lib/CMTAT` at tag `v3.0.0` (provides `IDebtEngine`, `ICMTATDebt`, and `CMTATStandaloneDebt` for tests)
- forge-std v1.13.0
- npm dev deps: `hardhat` 2.29, `@nomicfoundation/hardhat-foundry` 1.2, `surya`, `prettier-plugin-solidity`

## Common commands

```bash
forge build
forge test
forge fmt                      # formatter (forge fmt --check in CI-style checks)
forge coverage --report lcov --report-file doc/coverage/lcov.info --no-match-coverage "test/|script/" && genhtml doc/coverage/lcov.info --branch-coverage --output-dir doc/coverage/coverage
forge test --gas-report
npm run compile:hardhat                  # Hardhat compilation of src/ (needs forge for the remappings)
forge script script/DeployDebtEngine.s.sol --rpc-url $RPC_URL --account <keystore> --broadcast   # omit --broadcast to simulate
forge script script/ConnectDebtEngine.s.sol --rpc-url $RPC_URL --account <keystore> --broadcast
slither . --compile-force-framework foundry --checklist --filter-paths "openzeppelin-contracts|test|CMTAT|forge-std|script" > doc/tools/v0.3.0/slither-report.md   # runs forge clean
aderyn -x mocks --output doc/tools/v0.3.0/aderyn-report.md
bash doc/script/script_surya_graph.sh && bash doc/script/script_surya_inheritance.sh && bash doc/script/script_surya_report.sh
```

## Conventions

- **Versioning:** bump the private `VERSION` constant in `src/modules/VersionModule.sol`, the `testVersion` assertion in `test/DebtEngineBase.t.sol` and the README compatibility table; follow the checklist in `CHANGELOG.md`.
- **Changelog tags:** keepachangelog types plus `breaking change` (storage / external engine interface), `Dependencies`, `Documentation`, `Testing`.
- **Authorization hooks:** declared `internal view virtual` with no body in `DebtEngineBase`; every override keeps `internal view virtual override`, has an empty body and enforces the policy through the modifier (`onlyRole(ROLE)` / `onlyOwner`), never a bare `_checkRole` / `_checkOwner` call. Role constants live in the contract that enforces them (`DebtEngineAccessControl`), never in shared storage. The README access-control table (capability → role per variant) must be updated with any new hook.
- **New authorization policy:** add a deployment contract under `src/deployment/` that implements both `_authorize*` hooks and the `_msgSender` / `_msgData` / `_contextSuffixLength` overrides; add a test contract that extends `DebtEngineBaseTest`.
- **Security notes (see `doc/tools/v0.3.0/CLAUDE_AUDIT.md`):** an account holding `DEFAULT_ADMIN_ROLE` passes every role check, so granting it a manager role is a silent no-op and revoking one emits `RoleRevoked` without effect (F-1) — when handing admin over, renounce first and let the new admin grant manager roles; the trusted forwarder is trusted for every function, role management included (F-2).
- **Must not break:** the `IDebtEngine` interface (CMTAT calls it), zero-address checks, `MAX_BATCH_SIZE` and length checks on batches, event emission on every write.
- **Style:** NatSpec with `/** */`, section banners as in existing files; function attribute order visibility, mutability, `virtual`, `override`, modifiers (e.g. `internal view virtual override onlyOwner`); every public, external and overriding internal function is `virtual`; guards use `require(condition, CustomError(...))` (keep `if`/`revert` only where building the error arguments would cost an external call or storage read, with a comment saying so); every `if`/`for` body in braces; run `forge fmt` before committing.
- License: MPL-2.0 SPDX header on every source file.
