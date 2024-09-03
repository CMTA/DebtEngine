**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [solc-version](#solc-version) (1 results) (Informational)
 - [similar-names](#similar-names) (9 results) (Informational)
## solc-version

> The version in the config file is 0.8.26

Impact: Informational
Confidence: High
 - [ ] ID-0
	Version constraint ^0.8.20 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- VerbatimInvalidDeduplication
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess.
	 It is used by:
	- lib/CMTAT/contracts/interfaces/IDebtGlobal.sol#3
	- lib/CMTAT/contracts/interfaces/engine/IDebtEngine.sol#3
	- lib/openzeppelin-contracts/contracts/access/AccessControl.sol#4
	- lib/openzeppelin-contracts/contracts/access/IAccessControl.sol#4
	- lib/openzeppelin-contracts/contracts/utils/Context.sol#4
	- lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol#4
	- lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol#4
	- src/DebtEngine.sol#2
	- src/DebtEngineInvariantStorage.sol#2

## similar-names

> Acknowledge

Impact: Informational
Confidence: Medium
 - [ ] ID-1
Variable [DebtEngine.debt(address).smartContract_](src/DebtEngine.sol#L36) is too similar to [DebtEngine.setDebtBatch(address[],IDebtGlobal.DebtBase[]).smartContracts](src/DebtEngine.sol#L89)

src/DebtEngine.sol#L36


 - [ ] ID-2
Variable [DebtEngine.setCreditEvents(address,IDebtGlobal.CreditEvents).smartContract_](src/DebtEngine.sol#L69) is too similar to [DebtEngine.setDebtBatch(address[],IDebtGlobal.DebtBase[]).smartContracts](src/DebtEngine.sol#L89)

src/DebtEngine.sol#L69


 - [ ] ID-3
Variable [DebtEngine.creditEvents(address).smartContract_](src/DebtEngine.sol#L51) is too similar to [DebtEngine.setDebtBatch(address[],IDebtGlobal.DebtBase[]).smartContracts](src/DebtEngine.sol#L89)

src/DebtEngine.sol#L51


 - [ ] ID-4
Variable [DebtEngine.debt(address).smartContract_](src/DebtEngine.sol#L36) is too similar to [DebtEngine.setCreditEventsBatch(address[],IDebtGlobal.CreditEvents[]).smartContracts](src/DebtEngine.sol#L76)

src/DebtEngine.sol#L36


 - [ ] ID-5
Variable [DebtEngine.setDebt(address,IDebtGlobal.DebtBase).smartContract_](src/DebtEngine.sol#L62) is too similar to [DebtEngine.setCreditEventsBatch(address[],IDebtGlobal.CreditEvents[]).smartContracts](src/DebtEngine.sol#L76)

src/DebtEngine.sol#L62


 - [ ] ID-6
Variable [DebtEngine.setDebt(address,IDebtGlobal.DebtBase).smartContract_](src/DebtEngine.sol#L62) is too similar to [DebtEngine.setDebtBatch(address[],IDebtGlobal.DebtBase[]).smartContracts](src/DebtEngine.sol#L89)

src/DebtEngine.sol#L62


 - [ ] ID-7
Variable [DebtEngine.creditEvents(address).smartContract_](src/DebtEngine.sol#L51) is too similar to [DebtEngine.setCreditEventsBatch(address[],IDebtGlobal.CreditEvents[]).smartContracts](src/DebtEngine.sol#L76)

src/DebtEngine.sol#L51


 - [ ] ID-8
Variable [DebtEngine.setCreditEvents(address,IDebtGlobal.CreditEvents).smartContract_](src/DebtEngine.sol#L69) is too similar to [DebtEngine.setCreditEventsBatch(address[],IDebtGlobal.CreditEvents[]).smartContracts](src/DebtEngine.sol#L76)

src/DebtEngine.sol#L69


 - [ ] ID-9
Variable [DebtEngine._creditEvents](src/DebtEngine.sol#L12) is too similar to [DebtEngine.setCreditEvents(address,IDebtGlobal.CreditEvents).creditEvents_](src/DebtEngine.sol#L69)

src/DebtEngine.sol#L12

