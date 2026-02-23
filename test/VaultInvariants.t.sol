// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Vault} from "../contracts/core/Vault.sol";
import {VaultFactory} from "../contracts/core/VaultFactory.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract VaultInvariantsTest is Test {
    MockERC20 internal token;
    Vault internal vaultImplementation;
    VaultFactory internal factory;
    Vault internal vault;

    address internal governance = address(this);
    address internal custodian = address(0xBEEF);
    address internal user = address(0xCAFE);

    function setUp() external {
        token = new MockERC20();
        vaultImplementation = new Vault();
        factory = new VaultFactory(address(vaultImplementation), governance);
        factory.setSupportedUnderlying(address(token), true);

        address vaultAddr = factory.createVault(
            address(token),
            custodian,
            keccak256("salt-1")
        );
        vault = Vault(vaultAddr);

        token.mint(user, 1_000e18);
    }

    function testDepositPreservesLiabilityAndCustodyEquality() external {
        uint256 amount = 100e18;

        vm.startPrank(user);
        token.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();

        assertEq(vault.totalAssets(), amount);
        assertEq(vault.balances(user), amount);
        assertEq(token.balanceOf(address(vault)), amount);
        assertEq(vault.managedAssets(), amount);
        assertTrue(vault.solvency());
    }

    function testWithdrawPreservesLiabilityAndCustodyEquality() external {
        uint256 depositAmount = 100e18;
        uint256 withdrawAmount = 40e18;

        vm.startPrank(user);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vault.withdraw(withdrawAmount);
        vm.stopPrank();

        uint256 expected = depositAmount - withdrawAmount;
        assertEq(vault.totalAssets(), expected);
        assertEq(vault.balances(user), expected);
        assertEq(token.balanceOf(address(vault)), expected);
        assertEq(vault.managedAssets(), expected);
        assertTrue(vault.solvency());
    }

    function testEmergencyWithdrawPreservesManagedSolvencyModel() external {
        uint256 amount = 75e18;

        vm.startPrank(user);
        token.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();

        factory.triggerEmergency(address(vault));

        assertEq(vault.totalAssets(), amount);
        assertEq(vault.balances(user), amount);
        assertEq(token.balanceOf(address(vault)), 0);
        assertEq(vault.emergencyCustodiedAssets(), amount);
        assertEq(vault.managedAssets(), amount);
        assertTrue(vault.solvency());
    }

    function testOnlyGovernanceCanTriggerEmergency() external {
        vm.prank(user);
        vm.expectRevert();
        factory.triggerEmergency(address(vault));
    }

    function testOnlyGovernanceCanResolveEmergency() external {
        uint256 amount = 10e18;

        vm.startPrank(user);
        token.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();

        factory.triggerEmergency(address(vault));
        assertTrue(vault.emergencyMode());

        vm.prank(user);
        vm.expectRevert();
        factory.resolveEmergency(address(vault));

        vm.prank(custodian);
        token.transfer(address(vault), amount);

        factory.resolveEmergency(address(vault));
        assertTrue(!vault.emergencyMode());
    }
}
