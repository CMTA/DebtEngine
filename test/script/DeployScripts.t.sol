// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {DeployDebtEngine} from "../../script/DeployDebtEngine.s.sol";
import {ConnectDebtEngine} from "../../script/ConnectDebtEngine.s.sol";
import {DebtEngineBase} from "../../src/DebtEngineBase.sol";
import {DebtEngineAccessControl} from "../../src/deployment/DebtEngineAccessControl.sol";
import {DebtEngineOwnable} from "../../src/deployment/DebtEngineOwnable.sol";
import {ICMTATDebt} from "CMTAT/interfaces/tokenization/ICMTAT.sol";
import {IERC1643CMTAT} from "CMTAT/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {ISnapshotEngine} from "CMTAT/interfaces/engine/ISnapshotEngine.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IERC1643} from "CMTAT/interfaces/tokenization/draft-IERC1643.sol";
import {CMTATStandaloneDebt} from "CMTAT/deployment/debt/CMTATStandaloneDebt.sol";
import {ICMTATConstructor} from "CMTAT/interfaces/technical/ICMTATConstructor.sol";

/**
 * @dev Tests for script/DeployDebtEngine.s.sol and script/ConnectDebtEngine.s.sol.
 * The scripts broadcast from forge's default sender (`DEFAULT_SENDER`), which is the admin when none is given.
 */
contract DeployScriptsTest is Test {
    DeployDebtEngine internal deployScript;
    ConnectDebtEngine internal connectScript;

    address internal debtManager = address(0xDEB7);
    address internal creditManager = address(0xC2ED);
    address internal forwarder = address(0xF0F0);
    address internal otherAdmin = address(0xA11CE);

    function setUp() public {
        deployScript = new DeployDebtEngine();
        connectScript = new ConnectDebtEngine();
    }

    function _cfg(bool ownable, address admin, address fwd, address dm, address cm)
        internal
        pure
        returns (DeployDebtEngine.Config memory)
    {
        return DeployDebtEngine.Config({
            ownable: ownable, admin: admin, forwarder: fwd, debtManager: dm, creditEventsManager: cm
        });
    }

    function _token() internal returns (CMTATStandaloneDebt) {
        return new CMTATStandaloneDebt(
            DEFAULT_SENDER,
            ICMTATConstructor.ERC20Attributes("Bond", "BND", 0),
            ICMTATConstructor.ExtraInformationAttributes(
                "ISIN", IERC1643CMTAT.DocumentInfo("terms", "https://example.com", bytes32(0)), "info"
            ),
            ICMTATConstructor.Engine(IRuleEngine(address(0)), ISnapshotEngine(address(0)), IERC1643(address(0)))
        );
    }

    /*//////////////////////////////////////////////////////////////
                         DeployDebtEngine
    //////////////////////////////////////////////////////////////*/

    function testDeployAccessControlDefaults() public {
        DebtEngineBase engine = deployScript.deploy(_cfg(false, address(0), address(0), address(0), address(0)));
        DebtEngineAccessControl rbac = DebtEngineAccessControl(address(engine));

        assertEq(engine.version(), "0.3.0");
        assertTrue(rbac.hasRole(rbac.DEFAULT_ADMIN_ROLE(), DEFAULT_SENDER), "broadcaster is admin by default");
        assertFalse(rbac.isTrustedForwarder(address(0x1)));
    }

    function testDeployAccessControlWithManagersAndForwarder() public {
        DebtEngineBase engine = deployScript.deploy(_cfg(false, address(0), forwarder, debtManager, creditManager));
        DebtEngineAccessControl rbac = DebtEngineAccessControl(address(engine));

        assertEq(rbac.getRoleMember(rbac.DEBT_MANAGER_ROLE(), 0), debtManager);
        assertEq(rbac.getRoleMember(rbac.CREDIT_EVENTS_MANAGER_ROLE(), 0), creditManager);
        assertTrue(rbac.isTrustedForwarder(forwarder));

        // The granted manager can write
        ICMTATDebt.DebtInformation memory info;
        info.debtInstrument.parValue = 1;
        vm.prank(debtManager);
        engine.setDebt(address(0x1234), info);
        assertTrue(engine.hasDebt(address(0x1234)));
    }

    function testDeployAccessControlForAnotherAdmin() public {
        DebtEngineBase engine = deployScript.deploy(_cfg(false, otherAdmin, address(0), address(0), address(0)));
        DebtEngineAccessControl rbac = DebtEngineAccessControl(address(engine));
        assertTrue(rbac.hasRole(rbac.DEFAULT_ADMIN_ROLE(), otherAdmin));
        assertFalse(rbac.hasRole(rbac.DEFAULT_ADMIN_ROLE(), DEFAULT_SENDER), "broadcaster keeps no role");
    }

    function testDeployOwnable() public {
        DebtEngineBase engine = deployScript.deploy(_cfg(true, otherAdmin, address(0), address(0), address(0)));
        assertEq(DebtEngineOwnable(address(engine)).owner(), otherAdmin);
        assertTrue(DebtEngineOwnable(address(engine)).supportsInterface(0x7f5828d0));
    }

    function testRevertWhenGrantingManagersWithoutBeingAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(DeployDebtEngine.BroadcasterIsNotAdmin.selector, DEFAULT_SENDER, otherAdmin)
        );
        deployScript.deploy(_cfg(false, otherAdmin, address(0), debtManager, address(0)));
    }

    function testRevertWhenOwnableGivenManagers() public {
        vm.expectRevert(DeployDebtEngine.ManagersNeedAccessControlVariant.selector);
        deployScript.deploy(_cfg(true, address(0), address(0), debtManager, address(0)));
    }

    /// @dev The only test that touches the process environment, so parallel tests cannot race on it.
    function testRunReadsEnvironment() public {
        vm.setEnv("ENGINE_VARIANT", "ownable");
        vm.setEnv("ENGINE_ADMIN", vm.toString(otherAdmin));
        vm.setEnv("FORWARDER", vm.toString(forwarder));
        vm.setEnv("DEBT_MANAGER", vm.toString(address(0)));
        vm.setEnv("CREDIT_EVENTS_MANAGER", vm.toString(address(0)));

        DebtEngineBase engine = deployScript.run();
        assertEq(DebtEngineOwnable(address(engine)).owner(), otherAdmin);
        assertTrue(DebtEngineOwnable(address(engine)).isTrustedForwarder(forwarder));

        vm.setEnv("ENGINE_VARIANT", "proxy");
        vm.expectRevert(abi.encodeWithSelector(DeployDebtEngine.UnknownVariant.selector, "proxy"));
        deployScript.readConfig();

        vm.setEnv("ENGINE_VARIANT", "access-control");
    }

    /*//////////////////////////////////////////////////////////////
                         ConnectDebtEngine
    //////////////////////////////////////////////////////////////*/

    function testConnectAfterRecordIsWritten() public {
        DebtEngineBase engine = deployScript.deploy(_cfg(false, address(0), address(0), address(0), address(0)));
        CMTATStandaloneDebt token = _token();

        ICMTATDebt.DebtInformation memory info;
        info.debtInstrument.parValue = 1000;
        vm.prank(DEFAULT_SENDER);
        engine.setDebt(address(token), info);

        connectScript.connect(
            ConnectDebtEngine.Config({token: address(token), engine: address(engine), allowEmptyRecord: false})
        );

        assertEq(address(token.debtEngine()), address(engine));
        assertEq(token.debt().debtInstrument.parValue, 1000);
    }

    function testConnectRefusesEmptyRecord() public {
        DebtEngineBase engine = deployScript.deploy(_cfg(false, address(0), address(0), address(0), address(0)));
        CMTATStandaloneDebt token = _token();

        vm.expectRevert(
            abi.encodeWithSelector(ConnectDebtEngine.NoDebtRecordForToken.selector, address(engine), address(token))
        );
        connectScript.connect(
            ConnectDebtEngine.Config({token: address(token), engine: address(engine), allowEmptyRecord: false})
        );
        assertEq(address(token.debtEngine()), address(0));
    }

    function testConnectWithEmptyRecordWhenAllowed() public {
        DebtEngineBase engine = deployScript.deploy(_cfg(false, address(0), address(0), address(0), address(0)));
        CMTATStandaloneDebt token = _token();

        connectScript.connect(
            ConnectDebtEngine.Config({token: address(token), engine: address(engine), allowEmptyRecord: true})
        );
        assertEq(address(token.debtEngine()), address(engine));
    }
}
