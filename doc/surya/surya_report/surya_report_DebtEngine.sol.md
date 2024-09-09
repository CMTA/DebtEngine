## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./DebtEngine.sol | [object Promise] |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **DebtEngine** | Implementation | IDebtEngine, AccessControl, DebtEngineInvariantStorage, ERC2771Context |||
| └ | <Constructor> | Public ❗️ | 🛑  | ERC2771Context |
| └ | debt | External ❗️ |   |NO❗️ |
| └ | debt | Public ❗️ |   |NO❗️ |
| └ | creditEvents | External ❗️ |   |NO❗️ |
| └ | creditEvents | Public ❗️ |   |NO❗️ |
| └ | setDebt | External ❗️ | 🛑  | onlyRole |
| └ | setCreditEvents | External ❗️ | 🛑  | onlyRole |
| └ | setCreditEventsBatch | External ❗️ | 🛑  | onlyRole |
| └ | setDebtBatch | External ❗️ | 🛑  | onlyRole |
| └ | hasRole | Public ❗️ |   |NO❗️ |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
