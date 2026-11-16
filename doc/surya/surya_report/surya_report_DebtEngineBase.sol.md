## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./DebtEngineBase.sol | [object Promise] |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **DebtEngineBase** | Implementation | IDebtEngine, DebtEngineInvariantStorage, VersionModule |||
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
| └ | _setDebt | Internal 🔒 | 🛑  | |
| └ | _setCreditEvents | Internal 🔒 | 🛑  | |
| └ | _authorizeSetDebt | Internal 🔒 |   | |
| └ | _authorizeSetCreditEvents | Internal 🔒 |   | |
| └ | _msgSender | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
