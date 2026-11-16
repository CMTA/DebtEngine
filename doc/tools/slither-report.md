**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [dead-code](#dead-code) (1 results) (Informational)
 - [solc-version](#solc-version) (1 results) (Informational)
 - [similar-names](#similar-names) (9 results) (Informational)
## dead-code

> Acknowledge

Impact: Informational
Confidence: Medium

 - [ ] ID-0
[DebtEngine._msgData()](src/DebtEngine.sol#L160-L167) is never used and should be removed

src/DebtEngine.sol#L160-L167

## solc-version

> The version in the config file is 0.8.26

Impact: Informational
Confidence: High
 - [ ] ID-1
	Version constraint ^0.8.20 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- VerbatimInvalidDeduplication
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess.
	 It is used by:
	- lib/CMTAT/contracts/interfaces/IDebtGlobal.sol#3
	- lib/CMTAT/contracts/interfaces/engine/IDebtEngine.sol#3
	- lib/openzeppelin-contracts/contracts/access/AccessControl.sol#4
	- lib/openzeppelin-contracts/contracts/access/IAccessControl.sol#4
	- lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol#4
	- lib/openzeppelin-contracts/contracts/utils/Context.sol#4
	- lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol#4
	- lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol#4
	- src/DebtEngine.sol#2
	- src/DebtEngineInvariantStorage.sol#2

## similar-names

> Acknowledge

Impact: Informational
Confidence: Medium

 - [ ] ID-2
Variable [DebtEngine.debt(address).smartContract_](src/DebtEngine.sol#L48) is too similar to [DebtEngine.setDebtBatch(address[],IDebtGlobal.DebtBase[]).smartContracts](src/DebtEngine.sol#L112)

src/DebtEngine.sol#L48


 - [ ] ID-3
Variable [DebtEngine.setCreditEvents(address,IDebtGlobal.CreditEvents).smartContract_](src/DebtEngine.sol#L86) is too similar to [DebtEngine.setDebtBatch(address[],IDebtGlobal.DebtBase[]).smartContracts](src/DebtEngine.sol#L112)

src/DebtEngine.sol#L86


 - [ ] ID-4
Variable [DebtEngine.creditEvents(address).smartContract_](src/DebtEngine.sol#L65) is too similar to [DebtEngine.setDebtBatch(address[],IDebtGlobal.DebtBase[]).smartContracts](src/DebtEngine.sol#L112)

src/DebtEngine.sol#L65


 - [ ] ID-5
Variable [DebtEngine.debt(address).smartContract_](src/DebtEngine.sol#L48) is too similar to [DebtEngine.setCreditEventsBatch(address[],IDebtGlobal.CreditEvents[]).smartContracts](src/DebtEngine.sol#L96)

src/DebtEngine.sol#L48


 - [ ] ID-6
Variable [DebtEngine.setDebt(address,IDebtGlobal.DebtBase).smartContract_](src/DebtEngine.sol#L76) is too similar to [DebtEngine.setCreditEventsBatch(address[],IDebtGlobal.CreditEvents[]).smartContracts](src/DebtEngine.sol#L96)

src/DebtEngine.sol#L76


 - [ ] ID-7
Variable [DebtEngine.setDebt(address,IDebtGlobal.DebtBase).smartContract_](src/DebtEngine.sol#L76) is too similar to [DebtEngine.setDebtBatch(address[],IDebtGlobal.DebtBase[]).smartContracts](src/DebtEngine.sol#L112)

src/DebtEngine.sol#L76


 - [ ] ID-8
Variable [DebtEngine.creditEvents(address).smartContract_](src/DebtEngine.sol#L65) is too similar to [DebtEngine.setCreditEventsBatch(address[],IDebtGlobal.CreditEvents[]).smartContracts](src/DebtEngine.sol#L96)

src/DebtEngine.sol#L65


 - [ ] ID-9
Variable [DebtEngine.setCreditEvents(address,IDebtGlobal.CreditEvents).smartContract_](src/DebtEngine.sol#L86) is too similar to [DebtEngine.setCreditEventsBatch(address[],IDebtGlobal.CreditEvents[]).smartContracts](src/DebtEngine.sol#L96)

src/DebtEngine.sol#L86


 - [ ] ID-10
Variable [DebtEngine._creditEvents](src/DebtEngine.sol#L19) is too similar to [DebtEngine.setCreditEvents(address,IDebtGlobal.CreditEvents).creditEvents_](src/DebtEngine.sol#L87)

src/DebtEngine.sol#L19

