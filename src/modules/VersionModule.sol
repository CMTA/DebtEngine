// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

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
