# Debt Engine

> This project has not been audited yet, please use at your own risk. For any questions, please contact [admin@cmta.ch](mailto:admin@cmta.ch).

This repository includes the DebtEngine contract for the [CMTAT](https://github.com/CMTA/CMTAT) token.

The DebtEngine allows defining `debt` and `credit events` for several different contracts.

## Data Structures

A `debt` is represented as a `DebtInformation` struct composed of two parts:

```solidity
struct DebtInformation {
    DebtIdentifier debtIdentifier;
    DebtInstrument debtInstrument;
}
```

**DebtIdentifier** — information on the issuer and other persons involved:

```solidity
struct DebtIdentifier {
    string issuerName;
    string issuerDescription;
    string guarantor;
    string debtHolder;
}
```

**DebtInstrument** — information on the instrument:

```solidity
struct DebtInstrument {
    uint256 interestRate;
    uint256 parValue;
    uint256 minimumDenomination;
    string issuanceDate;
    string maturityDate;
    string couponPaymentFrequency;
    string interestScheduleFormat;
    string interestPaymentDate;
    string dayCountConvention;
    string businessDayConvention;
    string currency;
    address currencyContract;
}
```

A `creditEvents` is defined with the following attributes:

```solidity
struct CreditEvents {
    bool flagDefault;
    bool flagRedeemed;
    string rating;
}
```

## Architecture

The DebtEngine uses a layered architecture:

- **`DebtEngineBase`** (abstract) — contains all business logic, mappings, events, and authorization hooks. Does not depend on any specific access control mechanism or meta-transaction standard.
- **Deployment contracts** — concrete contracts that wire in access control and ERC-2771 support:
  - **`DebtEngineAccessControl`** — uses OpenZeppelin `AccessControl` (RBAC) with granular `DEBT_MANAGER_ROLE` and `CREDIT_EVENTS_MANAGER_ROLE`.
  - **`DebtEngineOwnable`** — uses OpenZeppelin `Ownable` (single owner controls everything).

## Functions

| Function | Visibility | Access | Description |
| --- | --- | --- | --- |
| `debt()` | External | Public | Returns debt for the caller's contract |
| `debt(address)` | Public | Public | Returns debt for a specific contract |
| `creditEvents()` | External | Public | Returns credit events for the caller's contract |
| `creditEvents(address)` | Public | Public | Returns credit events for a specific contract |
| `hasDebt(address)` | External | Public | Returns true if debt has been explicitly set |
| `hasCreditEvents(address)` | External | Public | Returns true if credit events have been explicitly set |
| `setDebt(address, DebtInformation)` | External | Authorized | Set debt for a contract |
| `setCreditEvents(address, CreditEvents)` | External | Authorized | Set credit events for a contract |
| `setDebtBatch(address[], DebtInformation[])` | External | Authorized | Set debt for multiple contracts (max 500) |
| `setCreditEventsBatch(address[], CreditEvents[])` | External | Authorized | Set credit events for multiple contracts (max 500) |

## Events

| Event | Emitted when |
| --- | --- |
| `DebtSet(address indexed smartContract)` | Debt is set or updated for a contract |
| `CreditEventsSet(address indexed smartContract)` | Credit events are set or updated for a contract |

## Access Control

Authorization is pluggable via two internal hooks (`_authorizeSetDebt` and `_authorizeSetCreditEvents`) defined in `DebtEngineBase`. Each deployment variant implements these hooks differently.

### DebtEngineAccessControl (RBAC)

| Role | Permissions |
| --- | --- |
| `DEFAULT_ADMIN_ROLE` | Implicitly holds all roles. Can grant/revoke roles. |
| `DEBT_MANAGER_ROLE` | Can call `setDebt` and `setDebtBatch` |
| `CREDIT_EVENTS_MANAGER_ROLE` | Can call `setCreditEvents` and `setCreditEventsBatch` |

> **Note:** The `DEFAULT_ADMIN_ROLE` is a super-admin. Any account holding this role is treated as holding every role implicitly. This is **not** reflected by `getRoleMemberCount` or `getRoleMembers`.

### DebtEngineOwnable (Single Owner)

The owner can call all restricted functions. Ownership can be transferred via `transferOwnership` or permanently renounced via `renounceOwnership`.

## Compatibility

| Component | Compatible Versions |
| --- | --- |
| **DebtEngine v0.3.0** (unaudited) | CMTAT >= v3.0.0 |
| **DebtEngine v0.2.0** (unaudited) | CMTAT v2.5.0 (unaudited) |

## How to include it

While it has been designed for the CMTAT, the DebtEngine can be used with other contracts to define debt and credit events.

Import the `IDebtEngine` interface which declares the `debt` and `creditEvents` functions:

```solidity
interface IDebtEngine is ICMTATDebt, ICMTATCreditEvents {
    // Inherits debt() and creditEvents() from parent interfaces
}
```

This interface can be found in [CMTAT/contracts/interfaces/engine/IDebtEngine.sol](https://github.com/CMTA/CMTAT/blob/master/contracts/interfaces/engine/IDebtEngine.sol)

## Schema

### Inheritance

#### DebtEngineAccessControl

![surya_inheritance_DebtEngineAccessControl.sol](./doc/surya/surya_inheritance/surya_inheritance_DebtEngineAccessControl.sol.png)

#### DebtEngineOwnable

![surya_inheritance_DebtEngineOwnable.sol](./doc/surya/surya_inheritance/surya_inheritance_DebtEngineOwnable.sol.png)

### Graph

#### DebtEngineAccessControl

![surya_graph_DebtEngineAccessControl.sol](./doc/surya/surya_graph/surya_graph_DebtEngineAccessControl.sol.png)

#### DebtEngineOwnable

![surya_graph_DebtEngineOwnable.sol](./doc/surya/surya_graph/surya_graph_DebtEngineOwnable.sol.png)

## Surya Description Report

### Contracts Description Table

#### DebtEngineBase

|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **DebtEngineBase** | Implementation | IDebtEngine, DebtEngineInvariantStorage |||
| └ | debt | External ❗️ |   |NO❗️ |
| └ | debt | Public ❗️ |   |NO❗️ |
| └ | creditEvents | External ❗️ |   |NO❗️ |
| └ | creditEvents | Public ❗️ |   |NO❗️ |
| └ | hasDebt | External ❗️ |   |NO❗️ |
| └ | hasCreditEvents | External ❗️ |   |NO❗️ |
| └ | setDebt | External ❗️ | 🛑  | onlyDebtManager |
| └ | setCreditEvents | External ❗️ | 🛑  | onlyCreditEventsManager |
| └ | setCreditEventsBatch | External ❗️ | 🛑  | onlyCreditEventsManager |
| └ | setDebtBatch | External ❗️ | 🛑  | onlyDebtManager |
| └ | _authorizeSetDebt | Internal 🔒 | 🛑  | |
| └ | _authorizeSetCreditEvents | Internal 🔒 | 🛑  | |
| └ | _msgSender | Internal 🔒 |   | |

#### DebtEngineAccessControl

|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **DebtEngineAccessControl** | Implementation | DebtEngineBase, AccessControl, ERC2771Context |||
| └ | <Constructor> | Public ❗️ | 🛑  | ERC2771Context |
| └ | _authorizeSetDebt | Internal 🔒 |   | |
| └ | _authorizeSetCreditEvents | Internal 🔒 |   | |
| └ | hasRole | Public ❗️ |   |NO❗️ |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |

#### DebtEngineOwnable

|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **DebtEngineOwnable** | Implementation | DebtEngineBase, Ownable, ERC2771Context |||
| └ | <Constructor> | Public ❗️ | 🛑  | ERC2771Context Ownable |
| └ | _authorizeSetDebt | Internal 🔒 |   | |
| └ | _authorizeSetCreditEvents | Internal 🔒 |   | |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |

### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |

Full reports: [./doc/surya/surya_report](./doc/surya/surya_report)

## Gasless support (ERC-2771)

The deployment contracts (`DebtEngineAccessControl` and `DebtEngineOwnable`) support client-side gasless transactions using the [Gas Station Network](https://docs.opengsn.org/#the-problem) (GSN) pattern, the main open standard for transferring fee payment to another account than that of the transaction issuer. The contracts use the OpenZeppelin `ERC2771Context` contract, which allows a contract to get the original client with `_msgSender()` instead of the fee payer given by `msg.sender`.

The abstract base (`DebtEngineBase`) does not depend on `ERC2771Context` directly — it defines a virtual `_msgSender()` that returns `msg.sender` by default. The deployment contracts override this with `ERC2771Context._msgSender()`.

At deployment, the parameter `forwarder` inside the constructor has to be set with the address of the forwarder.

> **Important:** The trusted forwarder address is **immutable** — it is set once at construction time and cannot be changed afterward. If the forwarder contract is compromised or needs to be rotated, a new DebtEngine must be deployed. Set the forwarder to `address(0)` to disable meta-transaction support entirely.

Please see the OpenGSN [documentation](https://docs.opengsn.org/contracts/#receiving-a-relayed-call) for more details on what is done to support GSN in the contract.

## Dependencies

The toolchain includes the following components, where the versions are the latest ones that we tested:

- Foundry
- Solidity 0.8.20+
- OpenZeppelin Contracts (submodule) v5.x
- Tests
  - [CMTAT v3.2.0-rc2](https://github.com/CMTA/CMTAT)
  - OpenZeppelin Contracts Upgradeable (submodule) v5.x

The CMTAT contracts and the OpenZeppelin library are included as submodules of the present repository.

## Tools

### Format

```bash
forge fmt
```

### Slither

```bash
slither .  --checklist --filter-paths "openzeppelin-contracts|test|CMTAT|forge-std" > doc/tools/slither-report.md
```

### Aderyn

```bash
aderyn . -o doc/tools/aderyn-report.md
```

### Surya

Run the 3 scripts in [./doc/script](./doc/script); the output is written to [./doc/surya](./doc/surya).

### Foundry

#### Build

```shell
forge build
```

#### Test

```shell
forge test
```

#### Coverage

```bash
forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage
```

#### Gas report

```bash
forge test --gas-report
```

## Intellectual property

The code is copyright (c) Capital Market and Technology Association, 2018-2026, and is released under [Mozilla Public License 2.0](https://github.com/CMTA/CMTAT/blob/master/LICENSE.md).
