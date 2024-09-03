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
| **DebtEngine** | Implementation | IDebtEngine, AccessControl, DebtEngineInvariantStorage |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
| └ | debt | External ❗️ |   |NO❗️ |
| └ | debt | Public ❗️ |   |NO❗️ |
| └ | creditEvents | External ❗️ |   |NO❗️ |
| └ | creditEvents | Public ❗️ |   |NO❗️ |
| └ | setDebt | External ❗️ | 🛑  | onlyRole |
| └ | setCreditEvents | External ❗️ | 🛑  | onlyRole |
| └ | setCreditEventsBatch | External ❗️ | 🛑  | onlyRole |
| └ | setDebtsBatch | External ❗️ | 🛑  | onlyRole |
| └ | hasRole | Public ❗️ |   |NO❗️ |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
