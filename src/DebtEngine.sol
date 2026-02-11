// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {AccessControl} from "OZ/access/AccessControl.sol";
import {ERC2771Context, Context} from "OZ/metatx/ERC2771Context.sol";
import {IDebtEngine} from "CMTAT/interfaces/engine/IDebtEngine.sol";
import {DebtEngineInvariantStorage} from "./DebtEngineInvariantStorage.sol";

contract DebtEngine is
    IDebtEngine,
    AccessControl,
    DebtEngineInvariantStorage,
    ERC2771Context
{
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

    /**
     * Constructor to initialize the admin role
     */
    constructor(
        address admin,
        address forwarderIrrevocable
    ) ERC2771Context(forwarderIrrevocable) {
        if (admin == address(0)) {
            revert AdminWithAddressZeroNotAllowed();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

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
    function debt(
        address smartContract_
    ) public view returns (DebtInformation memory) {
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
    function creditEvents(
        address smartContract_
    ) public view returns (CreditEvents memory) {
        return _creditEvents[smartContract_];
    }

    /* ============ RESTRICTED-FACING FUNCTIONS ============ */
    /**
     * @notice Function to set the debt for a given smart contract
     */
    function setDebt(
        address smartContract_,
        DebtInformation calldata debt_
    ) external onlyRole(DEBT_MANAGER_ROLE) {
        if (smartContract_ == address(0)) {
            revert SmartContractWithAddressZeroNotAllowed();
        }
        _debts[smartContract_] = debt_;
        emit DebtSet(smartContract_);
    }

    /**
     * @notice Function to set the credit events for a given smart contract
     */
    function setCreditEvents(
        address smartContract_,
        CreditEvents calldata creditEvents_
    ) external onlyRole(CREDIT_EVENTS_MANAGER_ROLE) {
        if (smartContract_ == address(0)) {
            revert SmartContractWithAddressZeroNotAllowed();
        }
        _creditEvents[smartContract_] = creditEvents_;
        emit CreditEventsSet(smartContract_);
    }

    /**
     * @notice Batch version of {setCreditEvents}
     */
    function setCreditEventsBatch(
        address[] calldata smartContracts,
        CreditEvents[] calldata creditEventsList
    ) external onlyRole(CREDIT_EVENTS_MANAGER_ROLE) {
        if (smartContracts.length != creditEventsList.length) {
            revert InvalidInputLength();
        }

        for (uint256 i = 0; i < smartContracts.length; i++) {
            if (smartContracts[i] == address(0)) {
                revert SmartContractWithAddressZeroNotAllowed();
            }
            _creditEvents[smartContracts[i]] = creditEventsList[i];
            emit CreditEventsSet(smartContracts[i]);
        }
    }

    /**
     * @notice Batch version of {setDebt}
     */
    function setDebtBatch(
        address[] calldata smartContracts,
        DebtInformation[] calldata debts
    ) external onlyRole(DEBT_MANAGER_ROLE) {
        if (smartContracts.length != debts.length) {
            revert InvalidInputLength();
        }

        for (uint256 i = 0; i < smartContracts.length; i++) {
            if (smartContracts[i] == address(0)) {
                revert SmartContractWithAddressZeroNotAllowed();
            }
            _debts[smartContracts[i]] = debts[i];
            emit DebtSet(smartContracts[i]);
        }
    }

    /* ============ ACCESS CONTROL ============ */

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(
        bytes32 role,
        address account
    ) public view virtual override returns (bool) {
        // The Default Admin has all roles
        if (AccessControl.hasRole(DEFAULT_ADMIN_ROLE, account)) {
            return true;
        }
        return AccessControl.hasRole(role, account);
    }

    /*//////////////////////////////////////////////////////////////
                           ERC2771
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev This surcharge is not necessary if you do not use ERC2771
     */
    function _msgSender()
        internal
        view
        override(ERC2771Context, Context)
        returns (address sender)
    {
        return ERC2771Context._msgSender();
    }

    /**
     * @dev This surcharge is not necessary if you do not use ERC2771
     */
    function _msgData()
        internal
        view
        override(ERC2771Context, Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }

    /**
     * @dev This surcharge is not necessary if you do not use the MetaTxModule
     */
    function _contextSuffixLength()
        internal
        view
        override(ERC2771Context, Context)
        returns (uint256)
    {
        return ERC2771Context._contextSuffixLength();
    }
}
