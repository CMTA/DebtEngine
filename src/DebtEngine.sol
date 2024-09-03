// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "OZ/access/AccessControl.sol";
import "CMTAT/interfaces/engine/IDebtEngine.sol";
import "./DebtEngineInvariantStorage.sol";
import {IDebtGlobal} from "CMTAT/interfaces/IDebtGlobal.sol";

contract DebtEngine is IDebtEngine, AccessControl, DebtEngineInvariantStorage {
    // Mapping of debts and credit events to specific smart contracts
    mapping(address => DebtBase) private _debts;
    mapping(address => CreditEvents) private _creditEvents;

    constructor(address admin) {
        if(admin == address(0)){
            revert AdminAddressZeroNotAllowed();
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
    function debt() external view returns (DebtBase memory) {
        return debt(msg.sender);
    }

    /** 
    * @notice Function to get the debt for a specific smart contract
    */
    function debt(address smartContract_) public view returns (DebtBase memory) {
        DebtBase memory d = _debts[smartContract_];
        return d;
    }

    /**
    * @notice Function to get the credit events for the sender's smart contract
    */
    function creditEvents() external view returns (CreditEvents memory) {
        return creditEvents(msg.sender);
    }

    /**
    * @notice Function to get the credit events for a specific smart contract
    */ 
    function creditEvents(address smartContract_) public view returns (CreditEvents memory) {
        CreditEvents memory ce = _creditEvents[smartContract_];
        return ce;
    }



    /* ============ RESTRICTED-FACING FUNCTIONS ============ */
    /**
    * @notice Function to set the debt for a given smart contract
    */
    function setDebt(address smartContract_, DebtBase calldata debt_) external onlyRole(DEBT_MANAGER_ROLE) {
        _debts[smartContract_] = debt_;
    }

    /*
    * @notice Function to set the credit events for a given smart contract
    */ 
    function setCreditEvents(address smartContract_, CreditEvents calldata creditEvents_) external onlyRole(CREDIT_EVENTS_MANAGER_ROLE) {
        _creditEvents[smartContract_] = creditEvents_;
    }

    /*
    * @notice Batch version of {setCreditEventsBatch}
    */ 
    function setCreditEventsBatch(address[] calldata smartContracts, CreditEvents[] calldata creditEventsList) external onlyRole(CREDIT_EVENTS_MANAGER_ROLE) {
        if (smartContracts.length != creditEventsList.length) {
            revert InvalidInputLength();
        }

        for (uint256 i = 0; i < smartContracts.length; i++) {
            _creditEvents[smartContracts[i]] = creditEventsList[i];
        }
    }

    /*
    * @notice Batch version of {setDebtBatch}
    */ 
    function setDebtBatch(address[] calldata smartContracts, DebtBase[] calldata debts) external onlyRole(DEBT_MANAGER_ROLE) {
        if (smartContracts.length != debts.length) {
            revert InvalidInputLength();
        }

        for (uint256 i = 0; i < smartContracts.length; i++) {
            _debts[smartContracts[i]] = debts[i];
        }
    }

    /* ============ ACCESS CONTROL ============ */

    /*
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
}