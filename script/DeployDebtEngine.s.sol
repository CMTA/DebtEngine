// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {DebtEngineBase} from "../src/DebtEngineBase.sol";
import {DebtEngineAccessControl} from "../src/deployment/DebtEngineAccessControl.sol";
import {DebtEngineOwnable} from "../src/deployment/DebtEngineOwnable.sol";

/**
 * @title Deploy a DebtEngine (RBAC or Ownable variant)
 * @dev Environment variables (all optional):
 * - `ENGINE_VARIANT`: `access-control` (default) or `ownable`.
 * - `ENGINE_ADMIN`: initial admin / owner; defaults to the broadcaster.
 * - `FORWARDER`: ERC-2771 trusted forwarder, immutable; defaults to `address(0)` (meta-transactions disabled).
 * - `DEBT_MANAGER`, `CREDIT_EVENTS_MANAGER` (RBAC only): granted the manager roles when set. Granting needs the
 *   broadcaster to be the admin.
 *
 * Usage:
 *   forge script script/DeployDebtEngine.s.sol --rpc-url $RPC_URL --account <keystore> --broadcast
 */
contract DeployDebtEngine is Script {
    struct Config {
        bool ownable;
        address admin;
        address forwarder;
        address debtManager;
        address creditEventsManager;
    }

    error UnknownVariant(string variant);
    error ManagersNeedAccessControlVariant();
    error BroadcasterIsNotAdmin(address broadcaster, address admin);

    function run() external returns (DebtEngineBase engine) {
        return deploy(readConfig());
    }

    /// @notice Reads the configuration from the environment (see the contract NatSpec).
    function readConfig() public view returns (Config memory cfg) {
        string memory variant = vm.envOr("ENGINE_VARIANT", string("access-control"));
        if (_eq(variant, "ownable")) {
            cfg.ownable = true;
        } else {
            require(_eq(variant, "access-control"), UnknownVariant(variant));
        }
        cfg.admin = vm.envOr("ENGINE_ADMIN", address(0));
        cfg.forwarder = vm.envOr("FORWARDER", address(0));
        cfg.debtManager = vm.envOr("DEBT_MANAGER", address(0));
        cfg.creditEventsManager = vm.envOr("CREDIT_EVENTS_MANAGER", address(0));
    }

    /**
     * @notice Deploys the engine described by `cfg`, grants the optional manager roles and checks the result.
     * @dev `cfg.admin == address(0)` means "the broadcaster".
     */
    function deploy(Config memory cfg) public returns (DebtEngineBase engine) {
        bool grantsManagers = cfg.debtManager != address(0) || cfg.creditEventsManager != address(0);
        require(!(cfg.ownable && grantsManagers), ManagersNeedAccessControlVariant());

        vm.startBroadcast();
        address broadcaster = _broadcaster();
        address admin = cfg.admin == address(0) ? broadcaster : cfg.admin;
        require(!grantsManagers || admin == broadcaster, BroadcasterIsNotAdmin(broadcaster, admin));

        if (cfg.ownable) {
            engine = new DebtEngineOwnable(admin, cfg.forwarder);
        } else {
            DebtEngineAccessControl rbac = new DebtEngineAccessControl(admin, cfg.forwarder);
            if (cfg.debtManager != address(0)) {
                rbac.grantRole(rbac.DEBT_MANAGER_ROLE(), cfg.debtManager);
            }
            if (cfg.creditEventsManager != address(0)) {
                rbac.grantRole(rbac.CREDIT_EVENTS_MANAGER_ROLE(), cfg.creditEventsManager);
            }
            engine = rbac;
        }
        vm.stopBroadcast();

        _check(engine, cfg, admin);
    }

    /// @dev Post-deployment checks: version, administrator, forwarder and granted roles.
    function _check(DebtEngineBase engine, Config memory cfg, address admin) internal view {
        require(_eq(engine.version(), "0.3.0"), "DebtEngine: unexpected version");
        if (cfg.ownable) {
            require(DebtEngineOwnable(address(engine)).owner() == admin, "DebtEngine: owner not set");
        } else {
            DebtEngineAccessControl rbac = DebtEngineAccessControl(address(engine));
            require(rbac.getRoleMember(rbac.DEFAULT_ADMIN_ROLE(), 0) == admin, "DebtEngine: admin not set");
            if (cfg.debtManager != address(0)) {
                require(rbac.hasRole(rbac.DEBT_MANAGER_ROLE(), cfg.debtManager), "DebtEngine: debt manager");
            }
            if (cfg.creditEventsManager != address(0)) {
                require(
                    rbac.hasRole(rbac.CREDIT_EVENTS_MANAGER_ROLE(), cfg.creditEventsManager),
                    "DebtEngine: credit events manager"
                );
            }
        }
        if (cfg.forwarder != address(0)) {
            require(DebtEngineAccessControl(address(engine)).isTrustedForwarder(cfg.forwarder), "DebtEngine: forwarder");
        }
    }

    function _broadcaster() internal returns (address sender) {
        (, sender,) = vm.readCallers();
    }

    function _eq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
