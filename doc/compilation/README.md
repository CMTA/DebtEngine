# Compilation files

Compiled artifacts of the two deployable contracts, `DebtEngineAccessControl` and `DebtEngineOwnable`, kept for each release so that a deployment can be reproduced or verified without rebuilding. Added for every release, not for release candidates.

## Layout

```
doc/compilation/
└── v<version>/
    ├── hardhat/deployment/<Contract>.sol/<Contract>.json      # Hardhat artifact (ABI, bytecode, deployedBytecode, link references)
    ├── hardhat/deployment/<Contract>.sol/<Contract>.dbg.json  # Hardhat debug pointer (the build-info file it names is not kept)
    ├── foundry/deployment/<Contract>.sol/<Contract>.json      # Foundry artifact (ABI, bytecode, method identifiers, solc metadata)
    └── flatten/<Contract>Flatten.sol                          # single-file source from `forge flatten`, for explorer verification
```

The layout follows CMTAT's `doc/hardhat-compilation/v<version>/` (artifacts under `deployment/`, flattened sources under `flatten/`), with a Foundry folder added next to the Hardhat one.

## v0.3.0

| | |
|---|---|
| Sources | `src/` of v0.3.0, including the F-4 fix (zero-address check in `_clearDebt` / `_clearCreditEvents`) |
| Compiler | solc 0.8.33, optimizer enabled, 200 runs, `evm_version = prague`, legacy pipeline (no `via_ir`) — identical in `foundry.toml` and `hardhat.config.js` |
| Tools | Foundry 1.5.0 (`forge build --force`), Hardhat 2.29.2 (`npx hardhat compile --force`) |
| Dependencies | CMTAT v3.0.0, OpenZeppelin Contracts v5.5.0 |

| Contract | Runtime size | Hardhat = Foundry | Flattened = Foundry |
|---|---|---|---|
| `DebtEngineAccessControl` | 9,268 bytes | ✅ | ✅ |
| `DebtEngineOwnable` | 7,772 bytes | ✅ | ✅ |

"=" means identical runtime bytecode once the trailing CBOR metadata is removed. The metadata hash differs between the three because it encodes the source paths, which are not the same in a Hardhat build, a Foundry build and a flattened file.

## Regenerating

```bash
V=v0.3.0   # the release version
npx hardhat compile --force
forge build --force
for c in DebtEngineAccessControl DebtEngineOwnable; do
  mkdir -p doc/compilation/$V/hardhat/deployment/$c.sol doc/compilation/$V/foundry/deployment/$c.sol doc/compilation/$V/flatten
  cp artifacts/src/deployment/$c.sol/$c.json artifacts/src/deployment/$c.sol/$c.dbg.json doc/compilation/$V/hardhat/deployment/$c.sol/
  cp out/$c.sol/$c.json doc/compilation/$V/foundry/deployment/$c.sol/
  forge flatten src/deployment/$c.sol -o doc/compilation/$V/flatten/${c}Flatten.sol
done
```

Then check the sizes against `forge build --sizes` and that the Hardhat and Foundry runtime bytecode match without metadata.
