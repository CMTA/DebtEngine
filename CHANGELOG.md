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

- Code: Update the version name in [./src/DebtEngineBase.sol](./src/DebtEngineBase.sol), constant `VERSION`, and the compatibility table in the [README](./README.md)
- Run linter

> forge fmt

- Run the tests

> forge test

- Documentation
  - Perform a code coverage and update the files in the corresponding directory [./doc/coverage](./doc/coverage)

  > forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage

  - Perform an audit with several audit tools (Aderyn and Slither), update the report in the corresponding directory [./doc/tools](./doc/tools)

  > slither . --checklist --filter-paths "openzeppelin-contracts|test|CMTAT|forge-std" > doc/tools/slither-report.md
  >
  > aderyn . -o doc/tools/aderyn-report.md

  - Update surya doc by running the 3 scripts in [./doc/script](./doc/script) (output in [./doc/surya](./doc/surya))

  > bash doc/script/script_surya_graph.sh && bash doc/script/script_surya_inheritance.sh && bash doc/script/script_surya_report.sh

  - Update changelog

## v0.3.0

- Update CMTAT library to v3.2.0-rc2
- Add `DebtSet` and `CreditEventsSet` events on state changes
- Add zero-address validation on `smartContract_` parameter
- Add `hasDebt(address)` and `hasCreditEvents(address)` view functions
- Add `MAX_BATCH_SIZE` (500) limit on `setDebtBatch` and `setCreditEventsBatch`
- Refactor into abstract `DebtEngineBase` with pluggable authorization hooks
- Add `DebtEngineAccessControl` deployment variant (OpenZeppelin `AccessControl`)
- Add `DebtEngineOwnable` deployment variant (OpenZeppelin `Ownable`)
- Move ERC-2771 support from base to deployment contracts
- Document `hasRole` super-admin behavior in NatSpec and README
- Document ERC-2771 forwarder immutability in README
- Fix NatSpec comments (`/*` to `/**`, self-referencing batch docs)
- Fix function modifier ordering (`internal view override`)
- Remove redundant memory variables in getter functions
- Remove unused `ICMTATDebt` and `ICMTATCreditEvents` imports
- Change `DebtEngineInvariantStorage` to `abstract contract`

## v0.2.0

Commit: `f6fb806b5f9b2ed7987500bb48bf8ea16346e85b`

- Add ERC-2771 support

## v0.1.0

Commit: `272c97e7953834794df8e0f32346236e6de9c7cd`

- first release!
