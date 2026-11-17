# CHANGELOG

Please follow https://changelog.md/ conventions.

## Type of changes

- `Added` for new features.
- `Changed` for changes in existing functionality.
- `Deprecated` for soon-to-be removed features.
- `Removed` for now removed features.
- `Fixed` for any bug fixes.
- `Security` in case of vulnerabilities.

Reference: [keepachangelog.com/en/1.1.0/](https://keepachangelog.com/en/1.1.0/)

Custom changelog tag

- `breaking change`: breaking change regarding storage [ERC-7201](https://eips.ethereum.org/EIPS/eip-7201) namespace , as well as external engine
- `Dependencies` (npm package, openzeppelin,...)
- `Documentation`
- `Testing`

## Checklist

> Before a new release, perform the following tasks

- Code: Update the version name in the `Version` module [./src/modules/VersionModule.sol](./src/modules/VersionModule.sol), constant `VERSION`, and the compatibility table in the [README](./README.md)
- Run linter

> forge fmt

- Run the tests

> forge test

- Documentation
  - Perform a code coverage and update the files in the corresponding directory [./doc/coverage](./doc/coverage)

  > forge coverage --report lcov --report-file doc/coverage/lcov.info --no-match-coverage "test/|script/" && genhtml doc/coverage/lcov.info --branch-coverage --output-dir doc/coverage/coverage

  - Perform an audit with several audit tools (Aderyn and Slither), update the report in the release directory `./doc/tools/<version>/` (e.g. [./doc/tools/v0.3.0](./doc/tools/v0.3.0))

  ```bash
  slither . --compile-force-framework foundry --checklist --filter-paths "openzeppelin-contracts|test|CMTAT|forge-std|script" > doc/tools/<version>/slither-report.md
  aderyn -x mocks --output doc/tools/<version>/aderyn-report.md
  ```

  - Update surya doc by running the 3 scripts in [./doc/script](./doc/script) (output in [./doc/surya](./doc/surya))

  > bash doc/script/script_surya_graph.sh && bash doc/script/script_surya_inheritance.sh && bash doc/script/script_surya_report.sh

  - For each new release (not for release candidates), add the Hardhat and Foundry compilation files in [./doc/compilation](./doc/compilation) (see its README)

  > npx hardhat compile --force && forge build --force

  - Update changelog

## v0.3.0

Commit: to be added on release

### Breaking change

- Split the single `DebtEngine` contract into an abstract `DebtEngineBase` and two deployment contracts, `DebtEngineAccessControl` and `DebtEngineOwnable`; deploy one of them instead of `DebtEngine`.
- Replace the public `VERSION` constant with a `version()` function, provided by the new `VersionModule` (same pattern as CMTAT `BaseModule`); integrators reading `VERSION()` must call `version()` instead.
- Move `DEBT_MANAGER_ROLE` and `CREDIT_EVENTS_MANAGER_ROLE` from `DebtEngineInvariantStorage` to `DebtEngineAccessControl`.

### Added

- Add a Hardhat configuration (`hardhat.config.js`, Hardhat 2 with the Foundry remappings) to compile `src/` with the same settings as Foundry; `npm run compile:hardhat`
- Add Foundry deployment scripts: `script/DeployDebtEngine.s.sol` (either variant, optional manager roles, post-deployment checks) and `script/ConnectDebtEngine.s.sol` (connects a CMTAT v3.0.0 debt token; refuses when the engine holds no record for the token)
- Add `DebtEngineAccessControl` deployment variant (OpenZeppelin `AccessControlEnumerable`, role holders listable on-chain)
- Add `DebtEngineOwnable` deployment variant (OpenZeppelin `Ownable2Step`, two-step ownership transfer)
- Add `VersionModule` (`src/modules/VersionModule.sol`) exposing `version()`
- Add `DebtSet` and `CreditEventsSet` events on state changes
- Add zero-address validation on `smartContract_` parameter (`SmartContractWithAddressZeroNotAllowed`)
- Add `hasDebt(address)` and `hasCreditEvents(address)` view functions; they return whether a record is currently set
- Add `clearDebt(address)` and `clearCreditEvents(address)` to delete a record, with `DebtCleared` / `CreditEventsCleared` events
  - Use: retire a token, or remove a record written to the wrong address; before this, a record could only be overwritten with an empty struct and `hasDebt` / `hasCreditEvents` stayed `true` forever.
  - Effect: the record and its `has*` flag are deleted, so `hasDebt` / `hasCreditEvents` return `false` and a CMTAT token pointing at the engine reads an empty record, as before it was set; clearing an unset record succeeds and still emits the event.
  - Access: gated by the same hooks as the setters (`DEBT_MANAGER_ROLE` / `CREDIT_EVENTS_MANAGER_ROLE`, or the owner); no new storage; runtime bytecode +617 bytes (`DebtEngineAccessControl` 8,573 → 9,190) and +587 bytes (`DebtEngineOwnable` 7,107 → 7,694).
- Add `MAX_BATCH_SIZE` (500) limit on `setDebtBatch` and `setCreditEventsBatch` (`BatchSizeTooLarge`)
- `DebtEngineOwnable` advertises ERC-173 (`0x7f5828d0`) and ERC-165 through `supportsInterface`

### Changed

- Refactor into abstract `DebtEngineBase` with pluggable authorization hooks (`_authorizeSetDebt`, `_authorizeSetCreditEvents`)
- Move ERC-2771 support from base to deployment contracts
- Declare the authorization hooks `internal view virtual` and implement every override with an empty body guarded by `onlyRole(...)` / `onlyOwner` instead of direct `_checkRole` / `_checkOwner` calls (no behaviour change)
- Change `DebtEngineInvariantStorage` to `abstract contract`
- Pin compiler settings in `foundry.toml`: solc `0.8.33`, optimizer (200 runs), EVM version `prague`
- Route every write through one internal function per record type, `_setDebt` and `_setCreditEvents`, which own the zero-address check, the storage write, the `has*` flag and the event.
  - Each event now has a single emit site, so a future write path cannot forget it.
  - Gas: single setters +34 gas (one internal call); batches about 670 gas cheaper per entry; deployment about 110k gas cheaper; runtime code 551 bytes smaller.
- Mark every public and external function of `DebtEngineBase`, and the `_msgSender` / `_msgData` / `_contextSuffixLength` overrides, `virtual` (no gas or size change)
- Use `require(condition, CustomError())` for all guards instead of `if (...) { revert ...; }`; revert data is unchanged (batch calls +13 gas, as `BatchSizeTooLarge` arguments are now built on the success path)
- Raise the minimum compiler to `pragma ^0.8.27`, required by `require` with a custom error on the legacy pipeline (0.8.26 fails to compile)

### Fixed

- `clearDebt` / `clearCreditEvents` now reject `address(0)` with `SmartContractWithAddressZeroNotAllowed`, like `setDebt` / `setCreditEvents` (finding F-4 of the security audit); previously they accepted it and emitted a `*Cleared` event for `address(0)`
- Fix NatSpec comments (`/*` to `/**`, self-referencing batch docs)
- Fix function modifier ordering (`internal view override`)

### Removed

- Remove redundant memory variables in getter functions
- Remove unused `ICMTATDebt` and `ICMTATCreditEvents` imports

### Dependencies

- Add npm dev dependencies `hardhat` (^2.29.2) and `@nomicfoundation/hardhat-foundry` (^1.2.1)
- Update CMTAT library (submodule) to v3.0.0

### Documentation

- Add the v0.3.0 compilation files in `doc/compilation/v0.3.0/`: Hardhat and Foundry artifacts of `DebtEngineAccessControl` and `DebtEngineOwnable`, and their flattened sources (identical runtime bytecode across the three, metadata aside); restore the release-checklist step
- Add a deployment guide for CMTAT v3.0.0 debt tokens ([`doc/technical/guides/DEPLOY_DEBT_ENGINE_CMTAT_V3.0.0.md`](./doc/technical/guides/DEPLOY_DEBT_ENGINE_CMTAT_V3.0.0.md)): setup choices, roles on the engine and token side, deployment with both variants and with an upgradeable token, read workflow, operations, admin handover and troubleshooting
- Document that granting a manager role to an admin is a no-op and revoking one emits `RoleRevoked` without effect, with the admin-handover runbook (README, `hasRole` NatSpec)
- Document that the trusted forwarder is trusted for every function including role management, that renouncing the last admin freezes role management, and list the clear functions in the RBAC role table
- Add the Claude security audit report of v0.3.0: [`doc/tools/v0.3.0/CLAUDE_AUDIT.md`](./doc/tools/v0.3.0/CLAUDE_AUDIT.md) (0 Critical/High/Medium/Low, 4 Info)
- Document `hasRole` super-admin behavior in NatSpec and README
- Document ERC-2771 forwarder immutability in README
- Document the authorization-hook convention and a capability → role table per deployment variant in README
- Document which CMTAT version each DebtEngine release is compatible with and was tested against in README
- Document that `MAX_BATCH_SIZE` is a ceiling and that the mainnet per-transaction gas cap (EIP-7825) limits batches first (NatSpec and README)
- Surya scripts now write to `doc/surya` and can be run from any directory; diagrams and reports regenerated for the new contracts
- Move the tool reports to a per-release directory, `doc/tools/v0.3.0/` (Slither, new Aderyn report, code-quality review `CLAUDE_ANALYSIS.md`); remove the earlier draft AI reviews
- Refresh the static analysis and coverage for v0.3.0: Slither 0.11.6 (0 High / 0 Medium / 0 Low / 2 Info) and Aderyn 0.6.5 (0 High / 7 Low), each with a feedback file triaging every finding (nothing to fix), a new audit overview (`doc/tools/AUDIT_OVERVIEW.md`), and coverage regenerated for the production sources (94.94% lines, 100% branches)
- Add agent guide (`CLAUDE.md` / `AGENTS.md`)
- Adapt the release checklist to this project's commands and directories

### Testing

- Add `test/script/DeployScripts.t.sol` for both deployment scripts (defaults, managers, forwarder, Ownable, environment parsing, refusal of an empty record, guard reverts)
- Add `DeployGuideCMTATv3.0.0.t.sol`, which runs every step of the CMTAT v3.0.0 deployment guide against real `CMTATStandaloneDebt` and proxied `CMTATUpgradeableDebt` tokens
- Add `DebtEngineThreatModel.t.sol` from the security audit ([`CLAUDE_AUDIT.md`](./doc/tools/v0.3.0/CLAUDE_AUDIT.md)): proofs of concept for the role-bookkeeping behaviour of the implicit admin, the trusted forwarder and token-local debt shadowing, plus fuzz tests that every writer rejects unauthorized callers in both variants and that set / clear sequences match a model
- Split tests into a shared abstract suite (`DebtEngineBaseTest`) run against both deployment variants
- Add `version()` test
- Add `clearDebt` / `clearCreditEvents` tests in the shared suite (clear, independence from the other record type and other tokens, clear of an unset record, set after clear, unauthorized caller, CMTAT token reads an empty record) and role-separation tests for the RBAC variant
- Add role-separation tests (`DEBT_MANAGER_ROLE` cannot set credit events and vice versa) and a role-constant test for `DebtEngineAccessControl`
- Add role-enumeration, implicit-admin-not-enumerated and ERC-165 tests for `DebtEngineAccessControl`
- Add two-step ownership handover tests for `DebtEngineOwnable`
- Adapt the CMTAT deployment in the test setup to CMTAT v3.0.0 (`BaseModuleAttributes` renamed to `ExtraInformationAttributes`)
- Add batch-size tests: `BatchSizeTooLarge` above `MAX_BATCH_SIZE` and success at exactly `MAX_BATCH_SIZE`, for both batch setters
- Add batch edge-case tests: empty batches emit nothing, a duplicated address keeps the last write and emits twice, more addresses than records reverts with `InvalidInputLength`
- Add fuzz tests checking that what `setDebt` / `setCreditEvents` write is what the getters return
- Add ERC-2771 tests: a trusted forwarder relays an authorized signer, cannot relay an unauthorized one, and a non-forwarder cannot spoof the sender by appending an address
- Add ERC-165 / ERC-173 tests for `DebtEngineOwnable`, including `OwnershipTransferred` at deployment
- Add `DebtEngineHarness`, a test-only engine that overrides public functions (so removing `virtual` breaks the build) and covers the base `_msgSender()`

## v0.2.0

Commit: `f6fb806b5f9b2ed7987500bb48bf8ea16346e85b`

- Add ERC-2771 support

## v0.1.0

Commit: `272c97e7953834794df8e0f32346236e6de9c7cd`

- first release!
