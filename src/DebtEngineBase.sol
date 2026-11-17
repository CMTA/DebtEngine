// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {IDebtEngine} from "CMTAT/interfaces/engine/IDebtEngine.sol";
import {DebtEngineInvariantStorage} from "./DebtEngineInvariantStorage.sol";
import {VersionModule} from "./modules/VersionModule.sol";

abstract contract DebtEngineBase is IDebtEngine, DebtEngineInvariantStorage, VersionModule {
    // Events
    event DebtSet(address indexed smartContract);
    event CreditEventsSet(address indexed smartContract);
    event DebtCleared(address indexed smartContract);
    event CreditEventsCleared(address indexed smartContract);

    // Mapping of debts and credit events to specific smart contracts
    mapping(address => DebtInformation) private _debts;
    mapping(address => CreditEvents) private _creditEvents;

    // Track whether debt/credit events have been explicitly set
    mapping(address => bool) private _debtSet;
    mapping(address => bool) private _creditEventsSet;

    /**
     * @notice Maximum number of entries accepted by `setDebtBatch` and `setCreditEventsBatch`.
     * @dev A hard ceiling, not a recommended batch size. Every entry writes its whole struct to storage,
     * so on a network with a per-transaction gas cap (Ethereum mainnet: 2^24 gas since EIP-7825) a batch
     * of realistic records runs out of gas long before this limit. Size batches from a gas estimate.
     */
    uint256 public constant MAX_BATCH_SIZE = 500;

    modifier onlyDebtManager() {
        _authorizeSetDebt();
        _;
    }

    modifier onlyCreditEventsManager() {
        _authorizeSetCreditEvents();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /* ============  USER-FACING FUNCTIONS ============ */
    /**
     * @notice  Function to get the debt for the sender's smart contract
     */
    function debt() external view virtual returns (DebtInformation memory) {
        return debt(_msgSender());
    }

    /**
     * @notice Function to get the debt for a specific smart contract
     */
    function debt(address smartContract_) public view virtual returns (DebtInformation memory) {
        return _debts[smartContract_];
    }

    /**
     * @notice Function to get the credit events for the sender's smart contract
     */
    function creditEvents() external view virtual returns (CreditEvents memory) {
        return creditEvents(_msgSender());
    }

    /**
     * @notice Function to get the credit events for a specific smart contract
     */
    function creditEvents(address smartContract_) public view virtual returns (CreditEvents memory) {
        return _creditEvents[smartContract_];
    }

    /**
     * @notice Returns true if a debt record is currently set for the given smart contract
     * @dev True after {setDebt} / {setDebtBatch}, false again after {clearDebt}.
     */
    function hasDebt(address smartContract_) external view virtual returns (bool) {
        return _debtSet[smartContract_];
    }

    /**
     * @notice Returns true if credit events are currently set for the given smart contract
     * @dev True after {setCreditEvents} / {setCreditEventsBatch}, false again after {clearCreditEvents}.
     */
    function hasCreditEvents(address smartContract_) external view virtual returns (bool) {
        return _creditEventsSet[smartContract_];
    }

    /* ============ RESTRICTED-FACING FUNCTIONS ============ */
    /**
     * @notice Function to set the debt for a given smart contract
     */
    function setDebt(address smartContract_, DebtInformation calldata debt_) external virtual onlyDebtManager {
        _setDebt(smartContract_, debt_);
    }

    /**
     * @notice Function to set the credit events for a given smart contract
     */
    function setCreditEvents(address smartContract_, CreditEvents calldata creditEvents_)
        external
        virtual
        onlyCreditEventsManager
    {
        _setCreditEvents(smartContract_, creditEvents_);
    }

    /**
     * @notice Batch version of {setCreditEvents}
     */
    function setCreditEventsBatch(address[] calldata smartContracts, CreditEvents[] calldata creditEventsList)
        external
        virtual
        onlyCreditEventsManager
    {
        require(smartContracts.length == creditEventsList.length, InvalidInputLength());
        require(smartContracts.length <= MAX_BATCH_SIZE, BatchSizeTooLarge(smartContracts.length, MAX_BATCH_SIZE));

        for (uint256 i = 0; i < smartContracts.length; i++) {
            _setCreditEvents(smartContracts[i], creditEventsList[i]);
        }
    }

    /**
     * @notice Batch version of {setDebt}
     */
    function setDebtBatch(address[] calldata smartContracts, DebtInformation[] calldata debts)
        external
        virtual
        onlyDebtManager
    {
        require(smartContracts.length == debts.length, InvalidInputLength());
        require(smartContracts.length <= MAX_BATCH_SIZE, BatchSizeTooLarge(smartContracts.length, MAX_BATCH_SIZE));

        for (uint256 i = 0; i < smartContracts.length; i++) {
            _setDebt(smartContracts[i], debts[i]);
        }
    }

    /**
     * @notice Deletes the debt record of `smartContract_`; `hasDebt` returns false afterwards
     * and `debt(smartContract_)` returns the zero struct, as before any record was set.
     * @dev Reverts with {SmartContractWithAddressZeroNotAllowed} for `address(0)`. Clearing a contract that has
     * no record succeeds and still emits {DebtCleared}.
     */
    function clearDebt(address smartContract_) external virtual onlyDebtManager {
        _clearDebt(smartContract_);
    }

    /**
     * @notice Deletes the credit events of `smartContract_`; `hasCreditEvents` returns false afterwards
     * and `creditEvents(smartContract_)` returns the zero struct, as before any record was set.
     * @dev Reverts with {SmartContractWithAddressZeroNotAllowed} for `address(0)`. Clearing a contract that has
     * no record succeeds and still emits {CreditEventsCleared}.
     */
    function clearCreditEvents(address smartContract_) external virtual onlyCreditEventsManager {
        _clearCreditEvents(smartContract_);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Single write path for debt: rejects `address(0)`, stores the record, marks it as set
     * and emits {DebtSet}. Every public setter goes through it, so none can skip a step.
     */
    function _setDebt(address smartContract_, DebtInformation calldata debt_) internal virtual {
        require(smartContract_ != address(0), SmartContractWithAddressZeroNotAllowed());
        _debts[smartContract_] = debt_;
        _debtSet[smartContract_] = true;
        emit DebtSet(smartContract_);
    }

    /**
     * @dev Single write path for credit events: rejects `address(0)`, stores the record, marks it
     * as set and emits {CreditEventsSet}. Every public setter goes through it.
     */
    function _setCreditEvents(address smartContract_, CreditEvents calldata creditEvents_) internal virtual {
        require(smartContract_ != address(0), SmartContractWithAddressZeroNotAllowed());
        _creditEvents[smartContract_] = creditEvents_;
        _creditEventsSet[smartContract_] = true;
        emit CreditEventsSet(smartContract_);
    }

    /**
     * @dev Single delete path for debt: rejects `address(0)` (as `_setDebt` does), removes the record
     * and its "set" flag, emits {DebtCleared}.
     */
    function _clearDebt(address smartContract_) internal virtual {
        require(smartContract_ != address(0), SmartContractWithAddressZeroNotAllowed());
        delete _debts[smartContract_];
        delete _debtSet[smartContract_];
        emit DebtCleared(smartContract_);
    }

    /**
     * @dev Single delete path for credit events: rejects `address(0)` (as `_setCreditEvents` does),
     * removes the record and its "set" flag, emits {CreditEventsCleared}.
     */
    function _clearCreditEvents(address smartContract_) internal virtual {
        require(smartContract_ != address(0), SmartContractWithAddressZeroNotAllowed());
        delete _creditEvents[smartContract_];
        delete _creditEventsSet[smartContract_];
        emit CreditEventsCleared(smartContract_);
    }

    /* ============ AUTHORIZATION HOOKS ============ */

    /**
     * @notice Authorization hook invoked before any debt change (`setDebt`, `setDebtBatch`, `clearDebt`).
     * @dev Must revert if the caller is not allowed. Implemented by each deployment contract
     * with its access-control policy; `view` guarantees the check cannot mutate state.
     */
    function _authorizeSetDebt() internal view virtual;

    /**
     * @notice Authorization hook invoked before any credit-events change (`setCreditEvents`, `setCreditEventsBatch`,
     * `clearCreditEvents`).
     * @dev Must revert if the caller is not allowed. Implemented by each deployment contract
     * with its access-control policy; `view` guarantees the check cannot mutate state.
     */
    function _authorizeSetCreditEvents() internal view virtual;

    /* ============ CONTEXT ============ */

    /**
     * @dev Returns the sender of the transaction.
     * Can be overridden to support meta-transactions (ERC2771).
     */
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}
