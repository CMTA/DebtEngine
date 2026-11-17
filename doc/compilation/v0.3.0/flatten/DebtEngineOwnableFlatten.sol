// SPDX-License-Identifier: MPL-2.0
pragma solidity >=0.4.16 ^0.8.20 ^0.8.27;

// lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// src/DebtEngineInvariantStorage.sol

abstract contract DebtEngineInvariantStorage {
    error AdminWithAddressZeroNotAllowed();
    error BatchSizeTooLarge(uint256 size, uint256 maxSize);
    error InvalidInputLength();
    error SmartContractWithAddressZeroNotAllowed();
}

// lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol

// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/IERC165.sol)

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// src/modules/VersionModule.sol

abstract contract VersionModule {
    /* ============ State Variables ============ */
    /**
     * @dev
     * Get the current version of the smart contract
     */
    string private constant VERSION = "0.3.0";

    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns the current version of the smart contract
     */
    function version() public view virtual returns (string memory) {
        return VERSION;
    }
}

// lib/CMTAT/contracts/interfaces/tokenization/draft-IERC1643.sol

/**
* @title IERC1643 Document Management 
* @dev Part of the ERC1400 Security Token Standards
* Contrary to the original specification, use a struct Document to represent a Document
*/
interface IERC1643 {
     /// @dev Struct used to represent a document and its metadata.
    struct Document {
         // URI of the off-chain document (e.g., IPFS, HTTPS)
        string uri;  
         // Hash of the document content
        bytes32 documentHash; 
         // Timestamp of the last on-chain modification (set by the smart contract)
        uint256 lastModified;
    }

    // Document Management
    /**
     * @notice Retrieves a document by its registered name.
     * @param name The unique name used to identify the document.
     * @return document The associated document's metadata (URI, hash, timestamp).
     */
    function getDocument(string memory name) external view returns (Document memory document);
    /**
     * @notice Returns the list of all document names registered in the contract.
     * @return documentNames_ An array of strings representing all document identifiers.
     */
    function getAllDocuments() external view returns (string[] memory documentNames_);
}

// lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol

// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/ERC165.sol)

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC-165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165 is IERC165 {
    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol

// OpenZeppelin Contracts (last updated v5.5.0) (metatx/ERC2771Context.sol)

/**
 * @dev Context variant with ERC-2771 support.
 *
 * WARNING: Avoid using this pattern in contracts that rely on a specific calldata length as they'll
 * be affected by any forwarder whose `msg.data` is suffixed with the `from` address according to the ERC-2771
 * specification adding the address size in bytes (20) to the calldata size. An example of an unexpected
 * behavior could be an unintended fallback (or another function) invocation while trying to invoke the `receive`
 * function only accessible if `msg.data.length == 0`.
 *
 * WARNING: The usage of `delegatecall` in this contract is dangerous and may result in context corruption.
 * Any forwarded request to this contract triggering a `delegatecall` to itself will result in an invalid {_msgSender}
 * recovery.
 */
abstract contract ERC2771Context is Context {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private immutable _trustedForwarder;

    /**
     * @dev Initializes the contract with a trusted forwarder, which will be able to
     * invoke functions on this contract on behalf of other accounts.
     *
     * NOTE: The trusted forwarder can be replaced by overriding {trustedForwarder}.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address trustedForwarder_) {
        _trustedForwarder = trustedForwarder_;
    }

    /**
     * @dev Returns the address of the trusted forwarder.
     */
    function trustedForwarder() public view virtual returns (address) {
        return _trustedForwarder;
    }

    /**
     * @dev Indicates whether any particular address is the trusted forwarder.
     */
    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return forwarder == trustedForwarder();
    }

    /**
     * @dev Override for `msg.sender`. Defaults to the original `msg.sender` whenever
     * a call is not performed by the trusted forwarder or the calldata length is less than
     * 20 bytes (an address length).
     */
    function _msgSender() internal view virtual override returns (address) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (calldataLength >= contextSuffixLength && isTrustedForwarder(msg.sender)) {
            unchecked {
                return address(bytes20(msg.data[calldataLength - contextSuffixLength:]));
            }
        } else {
            return super._msgSender();
        }
    }

    /**
     * @dev Override for `msg.data`. Defaults to the original `msg.data` whenever
     * a call is not performed by the trusted forwarder or the calldata length is less than
     * 20 bytes (an address length).
     */
    function _msgData() internal view virtual override returns (bytes calldata) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (calldataLength >= contextSuffixLength && isTrustedForwarder(msg.sender)) {
            unchecked {
                return msg.data[:calldataLength - contextSuffixLength];
            }
        } else {
            return super._msgData();
        }
    }

    /**
     * @dev ERC-2771 specifies the context as being a single address (20 bytes).
     */
    function _contextSuffixLength() internal view virtual override returns (uint256) {
        return 20;
    }
}

// lib/openzeppelin-contracts/contracts/access/Ownable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// lib/CMTAT/contracts/interfaces/tokenization/draft-IERC1643CMTAT.sol

interface IERC1643CMTAT {
    struct DocumentInfo {
        string name;
        string uri;
        bytes32 documentHash;
 }
}
 

// lib/CMTAT/contracts/interfaces/tokenization/ICMTAT.sol

/**
* The issuer must be able to “deactivate” the smart contract, to prevent execution of transactions on
* the distributed ledger.
* Contrary to the “burn” function, the “deactivateContract” function
* affects all tokens in issuance, and not only some of them. 
* 
* a) This function is necessary to allow the issuer to carry out certain corporate actions 
* (e.g. share splits, reverse splits or mergers), which 
* require that all existing tokens are either canceled or immobilized and decoupled from the shares
* (i.e. the tokens no longer represent shares).
* 
* b) The “deactivateContract” function can also be used if the issuer decides that it no longer wishes
* to have its shares issued in the form of ledger-based securities
* 
* The “deactivateContract” function does not delete the smart contract’s 
* storage and code, i.e. tokens are not burned by the function, however it permanently and
* irreversibly deactivates the smart contract (unless a proxy is used). 
* 
*/
interface ICMTATDeactivate {
     /**
     * @notice Emitted when the contract is permanently deactivated.
     * @param account The address that performed the deactivation.
     */
    event Deactivated(address account);

     /* 
     * @notice Permanently deactivates the contract.
     * @dev 
     * This action is irreversible — once executed, the contract cannot be reactivated.
     * Requirements:
     * - The contract MUST be paused before deactivation is allowed.
     * Emits a {Deactivated} event.
     * WARNING: Use with caution. This action permanently disables core contract functionality.
     */
    function deactivateContract() external;

     /**
     * @notice Returns whether the contract has been permanently deactivated.
     * @return isDeactivated A boolean indicating the deactivation status.
     * @dev Returns `true` if `deactivateContract()` has been successfully called.
     */
    function deactivated() external view returns (bool isDeactivated) ;
}

/** 
* @title ICMTATBase - Core Tokenization Metadata Interface as part of CMTAT specification
* @notice Defines base properties and metadata structure for a tokenized asset.
* @dev Includes token ID, terms (using IERC1643-compliant document), and a general information field.
*/
interface ICMTATBase {
    /* ============ Struct ============ */
     /*
     * @dev A reference to (e.g. in the form of an Internet address) or a hash of the tokenization terms
     */ 
     struct Terms {
 	    string name;
 	    IERC1643.Document doc;
    }
    /* ============ Events ============ */
    /**
    * @notice Emitted when the general information field is updated.
    * @param newInformation The newly assigned metadata or descriptive text.
    */
    event Information(
        string newInformation
    );
    /**
     * @notice Emitted when new tokenization terms are set.
     * @param newTerm The new Terms structure containing name and document reference.
     */
    event Term(Terms newTerm);

    /**
     * @notice Emitted when the token ID is set or updated.
     * @param newTokenIdIndexed The token ID (indexed for filtering).
     * @param newTokenId The full token ID string.
     */
    event TokenId(string indexed newTokenIdIndexed, string newTokenId);

    /* ============ View Functions ============ */

    /*
    * @notice return tokenization tokenId
    */
    function tokenId() external view returns (string memory tokenId_);
    /*
    * @notice returns tokenization terms
    */
    function terms() external view returns (Terms memory terms_);

    /*
    * @notice returns information field
    */
    function information() external view returns (string memory information_);

    /* ============ Write Functions ============ */
    /**
     * @notice Sets a new tokenization token ID.
     * @param tokenId_ The token ID string to assign to the tokenized asset.
     */
    function setTokenId(
        string calldata tokenId_
    ) external ;

    /**
     * @notice Sets new tokenization terms using a document reference.
     * @param terms_ The `DocumentInfo` structure referencing the terms document (name + URI + hash).
     */
    function setTerms(IERC1643CMTAT.DocumentInfo calldata terms_) external;

    /**
     * @notice Sets or updates the general information field.
     * @param information_ A string describing token attributes, usage, or metadata URI.
     */
    function setInformation(
        string calldata information_
    ) external;
}

interface ICMTATCreditEvents {
     /**
     * @notice Returns credit events
     */
    function creditEvents() external view returns(CreditEvents memory creditEvents_);

    struct CreditEvents {
        bool flagDefault;
        bool flagRedeemed;
        string rating;
    }
}
/**
* @notice interface to represent debt tokens
*/
interface ICMTATDebt {
    struct DebtInformation {
        DebtIdentifier debtIdentifier;
        DebtInstrument debtInstrument;
    }
    /**
    * @dev Information on the issuer and other persons involved
    */
    struct DebtIdentifier {
        string issuerName;
        string issuerDescription;
        string guarantor;
        string debtHolder;
    }
    /**
    * dev Information on the Instruments
    */
    struct DebtInstrument {
        // uint256
        uint256 interestRate;
        uint256 parValue;
        uint256 minimumDenomination;
        // string
        string issuanceDate;
        string maturityDate;
        string couponPaymentFrequency;
        /*
        * Interest schedule format (if any). The purpose of the interest schedule is to set, in the parameters of the smart
        *   contract, the dates on which the interest payments accrue.
        *    - Format A: start date/end date/period
        *   - Format B: start date/end date/day of period (e.g. quarter or year)
        *    - Format C: date 1/date 2/date 3/….
        */
        string interestScheduleFormat;
        /*
        * - Format A: period (indicating the period between the accrual date for the interest payment and the date on
        *   which the payment is scheduled to be made)
        * - Format B: specific date
        */
        string interestPaymentDate;
        string dayCountConvention;
        string businessDayConvention;
        string currency; 
        // address
        address currencyContract;
    }
    /**
     * @notice Returns debt information
     */
    function debt() external view returns(DebtInformation memory debtInformation_);
}

// lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol

// OpenZeppelin Contracts (last updated v5.1.0) (access/Ownable2Step.sol)

/**
 * @dev Contract module which provides access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This extension of the {Ownable} contract includes a two-step mechanism to transfer
 * ownership, where the new owner must call {acceptOwnership} in order to replace the
 * old one. This can help prevent common mistakes, such as transfers of ownership to
 * incorrect accounts, or to contracts that are unable to interact with the
 * permission system.
 *
 * The initial owner is specified at deployment time in the constructor for `Ownable`. This
 * can later be changed with {transferOwnership} and {acceptOwnership}.
 *
 * This module is used through inheritance. It will make available all functions
 * from parent (Ownable).
 */
abstract contract Ownable2Step is Ownable {
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Returns the address of the pending owner.
     */
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /**
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     *
     * Setting `newOwner` to the zero address is allowed; this can be used to cancel an initiated ownership transfer.
     */
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }

    /**
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() public virtual {
        address sender = _msgSender();
        if (pendingOwner() != sender) {
            revert OwnableUnauthorizedAccount(sender);
        }
        _transferOwnership(sender);
    }
}

// lib/CMTAT/contracts/interfaces/engine/IDebtEngine.sol

/*
* @dev minimum interface to define a DebtEngine
*/
interface IDebtEngine is ICMTATDebt, ICMTATCreditEvents {
    // nothing more
}

// src/DebtEngineBase.sol

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

// src/deployment/DebtEngineOwnable.sol

/**
 * @notice DebtEngine deployment where a single owner manages both debt and credit events.
 * @dev Ownership transfer is two-step (`transferOwnership` then `acceptOwnership` by the new owner).
 * Every authorization hook collapses to `onlyOwner`, so this variant cannot separate duties.
 * Advertises ERC-173 (contract ownership) through ERC-165.
 */
contract DebtEngineOwnable is DebtEngineBase, Ownable2Step, ERC2771Context, ERC165 {
    /// @dev ERC-165 identifier of the ERC-173 interface (`owner()` ^ `transferOwnership(address)`).
    bytes4 private constant ERC173_INTERFACE_ID = 0x7f5828d0;

    constructor(address owner, address forwarderIrrevocable) ERC2771Context(forwarderIrrevocable) Ownable(owner) {}

    /* ============ ERC-165 ============ */

    /**
     * @inheritdoc ERC165
     * @dev Returns true for ERC-173 and ERC-165.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == ERC173_INTERFACE_ID || super.supportsInterface(interfaceId);
    }

    /* ============ AUTHORIZATION HOOKS ============ */

    function _authorizeSetDebt() internal view virtual override onlyOwner {}

    function _authorizeSetCreditEvents() internal view virtual override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                           ERC2771
    //////////////////////////////////////////////////////////////*/

    function _msgSender() internal view virtual override(DebtEngineBase, ERC2771Context, Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view virtual override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    function _contextSuffixLength() internal view virtual override(ERC2771Context, Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}
