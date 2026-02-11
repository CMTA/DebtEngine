// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {ERC2771Context} from "OZ/metatx/ERC2771Context.sol";
import {IDebtEngine} from "CMTAT/interfaces/engine/IDebtEngine.sol";
import {DebtEngineInvariantStorage} from "./DebtEngineInvariantStorage.sol";

abstract contract DebtEngine is IDebtEngine, DebtEngineInvariantStorage, ERC2771Context {
    /**
     * @notice
     * Get the current version of the smart contract
     */
    string public constant VERSION = "0.3.0";

    // Events
    event DebtSet(address indexed smartContract);
    event CreditEventsSet(address indexed smartContract);

    // Mapping of debts and credit events to specific smart contracts
    mapping(address => DebtInformation) private _debts;
    mapping(address => CreditEvents) private _creditEvents;

    // Track whether debt/credit events have been explicitly set
    mapping(address => bool) private _debtSet;
    mapping(address => bool) private _creditEventsSet;

    modifier onlyDebtManager() {
        _authorizeSetDebt();
        _;
    }

    modifier onlyCreditEventsManager() {
        _authorizeSetCreditEvents();
        _;
    }

    /**
     * Constructor to initialize ERC2771 forwarder
     */
    constructor(address forwarderIrrevocable) ERC2771Context(forwarderIrrevocable) {}

    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /* ============  USER-FACING FUNCTIONS ============ */
    /**
     * @notice  Function to get the debt for the sender's smart contract
     */
    function debt() external view returns (DebtInformation memory) {
        return debt(_msgSender());
    }

    /**
     * @notice Function to get the debt for a specific smart contract
     */
    function debt(address smartContract_) public view returns (DebtInformation memory) {
        return _debts[smartContract_];
    }

    /**
     * @notice Function to get the credit events for the sender's smart contract
     */
    function creditEvents() external view returns (CreditEvents memory) {
        return creditEvents(_msgSender());
    }

    /**
     * @notice Function to get the credit events for a specific smart contract
     */
    function creditEvents(address smartContract_) public view returns (CreditEvents memory) {
        return _creditEvents[smartContract_];
    }

    /**
     * @notice Returns true if debt has been set for the given smart contract
     */
    function hasDebt(address smartContract_) external view returns (bool) {
        return _debtSet[smartContract_];
    }

    /**
     * @notice Returns true if credit events have been set for the given smart contract
     */
    function hasCreditEvents(address smartContract_) external view returns (bool) {
        return _creditEventsSet[smartContract_];
    }

    /* ============ RESTRICTED-FACING FUNCTIONS ============ */
    /**
     * @notice Function to set the debt for a given smart contract
     */
    function setDebt(address smartContract_, DebtInformation calldata debt_) external onlyDebtManager {
        if (smartContract_ == address(0)) {
            revert SmartContractWithAddressZeroNotAllowed();
        }
        _debts[smartContract_] = debt_;
        _debtSet[smartContract_] = true;
        emit DebtSet(smartContract_);
    }

    /**
     * @notice Function to set the credit events for a given smart contract
     */
    function setCreditEvents(address smartContract_, CreditEvents calldata creditEvents_)
        external
        onlyCreditEventsManager
    {
        if (smartContract_ == address(0)) {
            revert SmartContractWithAddressZeroNotAllowed();
        }
        _creditEvents[smartContract_] = creditEvents_;
        _creditEventsSet[smartContract_] = true;
        emit CreditEventsSet(smartContract_);
    }

    /**
     * @notice Batch version of {setCreditEvents}
     */
    function setCreditEventsBatch(address[] calldata smartContracts, CreditEvents[] calldata creditEventsList)
        external
        onlyCreditEventsManager
    {
        if (smartContracts.length != creditEventsList.length) {
            revert InvalidInputLength();
        }

        for (uint256 i = 0; i < smartContracts.length; i++) {
            if (smartContracts[i] == address(0)) {
                revert SmartContractWithAddressZeroNotAllowed();
            }
            _creditEvents[smartContracts[i]] = creditEventsList[i];
            _creditEventsSet[smartContracts[i]] = true;
            emit CreditEventsSet(smartContracts[i]);
        }
    }

    /**
     * @notice Batch version of {setDebt}
     */
    function setDebtBatch(address[] calldata smartContracts, DebtInformation[] calldata debts)
        external
        onlyDebtManager
    {
        if (smartContracts.length != debts.length) {
            revert InvalidInputLength();
        }

        for (uint256 i = 0; i < smartContracts.length; i++) {
            if (smartContracts[i] == address(0)) {
                revert SmartContractWithAddressZeroNotAllowed();
            }
            _debts[smartContracts[i]] = debts[i];
            _debtSet[smartContracts[i]] = true;
            emit DebtSet(smartContracts[i]);
        }
    }

    /* ============ AUTHORIZATION HOOKS ============ */

    function _authorizeSetDebt() internal virtual;
    function _authorizeSetCreditEvents() internal virtual;

    /*//////////////////////////////////////////////////////////////
                           ERC2771
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev This surcharge is not necessary if you do not use ERC2771
     */
    function _msgSender() internal view virtual override returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /**
     * @dev This surcharge is not necessary if you do not use ERC2771
     */
    function _msgData() internal view virtual override returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /**
     * @dev This surcharge is not necessary if you do not use the MetaTxModule
     */
    function _contextSuffixLength() internal view virtual override returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}
