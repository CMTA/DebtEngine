// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {DebtEngineBase} from "../src/DebtEngineBase.sol";
import {IDebtEngine} from "CMTAT/interfaces/engine/IDebtEngine.sol";
import {DebtEngineModule} from "CMTAT/modules/wrapper/options/DebtEngineModule.sol";

/**
 * @title Connect a CMTAT v3.0.0 debt token to a DebtEngine
 * @dev Runs on the token side: the broadcaster must hold the token's `DEBT_ROLE` (CMTAT's `DEFAULT_ADMIN_ROLE`
 * implicitly does). For an upgradeable token, `TOKEN` is the proxy address.
 *
 * Environment variables:
 * - `TOKEN` (required): the CMTAT debt token (`CMTATStandaloneDebt` or the `CMTATUpgradeableDebt` proxy).
 * - `DEBT_ENGINE` (required): the engine to connect.
 * - `ALLOW_EMPTY_RECORD` (optional, default `false`): connect even if the engine holds no debt record for the
 *   token. Once connected, the token reads only the engine, so connecting first hides the token's own data.
 *
 * Usage:
 *   TOKEN=0x... DEBT_ENGINE=0x... forge script script/ConnectDebtEngine.s.sol --rpc-url $RPC_URL --account <keystore> --broadcast
 */
contract ConnectDebtEngine is Script {
    struct Config {
        address token;
        address engine;
        bool allowEmptyRecord;
    }

    error NoDebtRecordForToken(address engine, address token);

    function run() external {
        connect(
            Config({
                token: vm.envAddress("TOKEN"),
                engine: vm.envAddress("DEBT_ENGINE"),
                allowEmptyRecord: vm.envOr("ALLOW_EMPTY_RECORD", false)
            })
        );
    }

    /// @notice Checks the engine holds the token's record, connects the token, and checks the token now reads it.
    function connect(Config memory cfg) public {
        DebtEngineBase engine = DebtEngineBase(cfg.engine);
        require(cfg.allowEmptyRecord || engine.hasDebt(cfg.token), NoDebtRecordForToken(cfg.engine, cfg.token));

        vm.startBroadcast();
        DebtEngineModule(cfg.token).setDebtEngine(IDebtEngine(cfg.engine));
        vm.stopBroadcast();

        require(address(DebtEngineModule(cfg.token).debtEngine()) == cfg.engine, "DebtEngine: not connected");
    }
}
