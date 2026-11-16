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

  > forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage

  - Perform an audit with several audit tools (Aderyn and Slither), update the report in the corresponding directory [./doc/tools](./doc/tools)

  ```bash
  slither . --checklist --filter-paths "openzeppelin-contracts|test|CMTAT|forge-std" > doc/tools/slither-report.md
  aderyn . -o doc/tools/aderyn-report.md
  ```

  - Update surya doc by running the 3 scripts in [./doc/script](./doc/script) (output in [./doc/surya](./doc/surya))

  > bash doc/script/script_surya_graph.sh && bash doc/script/script_surya_inheritance.sh && bash doc/script/script_surya_report.sh

  - Update changelog

## v0.3.0

Branch: `dev` (not yet released, commit hash to be added on release)

### Breaking change

- Split the single `DebtEngine` contract into an abstract `DebtEngineBase` and two deployment contracts, `DebtEngineAccessControl` and `DebtEngineOwnable`; deploy one of them instead of `DebtEngine`.
- Replace the public `VERSION` constant with a `version()` function, provided by the new `VersionModule` (same pattern as CMTAT `BaseModule`); integrators reading `VERSION()` must call `version()` instead.
- Move `DEBT_MANAGER_ROLE` and `CREDIT_EVENTS_MANAGER_ROLE` from `DebtEngineInvariantStorage` to `DebtEngineAccessControl`.

### Added

- Add `DebtEngineAccessControl` deployment variant (OpenZeppelin `AccessControlEnumerable`, role holders listable on-chain)
- Add `DebtEngineOwnable` deployment variant (OpenZeppelin `Ownable2Step`, two-step ownership transfer)
- Add `VersionModule` (`src/modules/VersionModule.sol`) exposing `version()`
- Add `DebtSet` and `CreditEventsSet` events on state changes
- Add zero-address validation on `smartContract_` parameter (`SmartContractWithAddressZeroNotAllowed`)
- Add `hasDebt(address)` and `hasCreditEvents(address)` view functions
- Add `MAX_BATCH_SIZE` (500) limit on `setDebtBatch` and `setCreditEventsBatch` (`BatchSizeTooLarge`)

### Changed

- Refactor into abstract `DebtEngineBase` with pluggable authorization hooks (`_authorizeSetDebt`, `_authorizeSetCreditEvents`)
- Move ERC-2771 support from base to deployment contracts
- Declare the authorization hooks `internal view virtual` and implement every override with an empty body guarded by `onlyRole(...)` / `onlyOwner` instead of direct `_checkRole` / `_checkOwner` calls (no behaviour change)
- Change `DebtEngineInvariantStorage` to `abstract contract`
- Pin compiler settings in `foundry.toml`: solc `0.8.33`, optimizer (200 runs), EVM version `prague`

### Fixed

- Fix NatSpec comments (`/*` to `/**`, self-referencing batch docs)
- Fix function modifier ordering (`internal view override`)

### Removed

- Remove redundant memory variables in getter functions
- Remove unused `ICMTATDebt` and `ICMTATCreditEvents` imports

### Dependencies

- Update CMTAT library (submodule) to v3.0.0

### Documentation

- Document `hasRole` super-admin behavior in NatSpec and README
- Document ERC-2771 forwarder immutability in README
- Document the authorization-hook convention and a capability → role table per deployment variant in README
- Surya scripts now write to `doc/surya` and can be run from any directory; diagrams and reports regenerated for the new contracts
- Move the Slither report to `doc/tools/slither-report.md` and add an Aderyn report (`doc/tools/aderyn-report.md`)
- Add agent guide (`CLAUDE.md` / `AGENTS.md`) and `doc/tools/CLAUDE_ANALYSIS_SUMMARY.md`
- Adapt the release checklist to this project's commands and directories

### Testing

- Split tests into a shared abstract suite (`DebtEngineBaseTest`) run against both deployment variants
- Add `version()` test
- Add role-separation tests (`DEBT_MANAGER_ROLE` cannot set credit events and vice versa) and a role-constant test for `DebtEngineAccessControl`
- Add role-enumeration, implicit-admin-not-enumerated and ERC-165 tests for `DebtEngineAccessControl`
- Add two-step ownership handover tests for `DebtEngineOwnable`
- Adapt the CMTAT deployment in the test setup to CMTAT v3.0.0 (`BaseModuleAttributes` renamed to `ExtraInformationAttributes`)

## v0.2.0

Commit: `f6fb806b5f9b2ed7987500bb48bf8ea16346e85b`

- Add ERC-2771 support

## v0.1.0

Commit: `272c97e7953834794df8e0f32346236e6de9c7cd`

- first release!
