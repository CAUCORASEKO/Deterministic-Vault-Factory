// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVault} from "../interfaces/IVault.sol";
import {VaultErrors} from "../libraries/VaultErrors.sol";
import {VaultEvents} from "../libraries/VaultEvents.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Vault is IVault, ReentrancyGuard {
    event EmergencyCustodyMigrated(uint256 amount);

    // =============================================================
    //                         STORAGE
    // =============================================================

    // Identity
    address public factory;
    address public underlying;
    address public emergencyCustodian;

    // Accounting
    uint256 public totalAssets;
    uint256 public emergencyCustodiedAssets;
    mapping(address => uint256) public balances;

    // Operational
    bool public emergencyMode;

    // Initialization
    bool private _initialized;

    // =============================================================
    //                         MODIFIERS
    // =============================================================

    modifier onlyFactory() {
        _onlyFactory();
        _;
    }

    modifier notEmergency() {
        _notEmergency();
        _;
    }

    function _onlyFactory() internal view {
        if (msg.sender != factory) revert VaultErrors.NotFactory();
    }

    function _notEmergency() internal view {
        if (emergencyMode) revert VaultErrors.NotSolvent();
    }

    // =============================================================
    //                         CONSTRUCTOR
    // =============================================================

    constructor() {
        // Lock implementation
        _initialized = true;
    }

    // =============================================================
    //                         INITIALIZER
    // =============================================================

    function initialize(
        address underlying_,
        address custodian_
    ) external override {

        if (_initialized) revert VaultErrors.AlreadyInitialized();
        if (underlying_ == address(0) || custodian_ == address(0))
            revert VaultErrors.ZeroAddress();

        factory = msg.sender;
        underlying = underlying_;
        emergencyCustodian = custodian_;

        _initialized = true;

        emit VaultEvents.VaultInitialized(underlying_, msg.sender);
    }

    // =============================================================
    //                         DEPOSIT
    // =============================================================

    function deposit(uint256 amount)
        external
        override
        nonReentrant
        notEmergency
    {
        if (amount == 0) revert VaultErrors.InvalidSalt(); // reuse minimal error set

        IERC20 token = IERC20(underlying);

        uint256 balanceBefore = token.balanceOf(address(this));

        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) revert VaultErrors.NotSolvent();

        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 received = balanceAfter - balanceBefore;

        // Strict ERC20 enforcement
        if (received != amount) revert VaultErrors.NotSolvent();

        balances[msg.sender] += received;
        totalAssets += received;

        emit VaultEvents.Deposit(msg.sender, received);
    }

    // =============================================================
    //                         WITHDRAW
    // =============================================================

    function withdraw(uint256 amount)
        external
        override
        nonReentrant
        notEmergency
    {
        if (amount == 0) revert VaultErrors.InvalidSalt();

        uint256 userBalance = balances[msg.sender];
        if (userBalance < amount) revert VaultErrors.NotSolvent();

        balances[msg.sender] = userBalance - amount;
        totalAssets -= amount;

        bool success = IERC20(underlying).transfer(msg.sender, amount);
        if (!success) revert VaultErrors.NotSolvent();

        emit VaultEvents.Withdraw(msg.sender, amount);
    }

    function managedAssets() public view returns (uint256) {
        return IERC20(underlying).balanceOf(address(this)) + emergencyCustodiedAssets;
    }

    function solvency() public view returns (bool) {
        return managedAssets() >= totalAssets;
    }

    // =============================================================
    //                     EMERGENCY MODE
    // =============================================================

    function emergencyWithdraw()
        external
        override
        onlyFactory
        nonReentrant
    {
        if (emergencyMode) revert VaultErrors.NotSolvent();

        emergencyMode = true;

        IERC20 token = IERC20(underlying);
        uint256 balance = token.balanceOf(address(this));

        if (balance > 0) {
            emergencyCustodiedAssets += balance;

            bool success = token.transfer(
                emergencyCustodian,
                balance
            );
            if (!success) revert VaultErrors.NotSolvent();

            emit EmergencyCustodyMigrated(balance);
        }

        emit VaultEvents.EmergencyActivated(msg.sender);
    }
}
