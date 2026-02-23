// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVault} from "../interfaces/IVault.sol";
import {VaultErrors} from "../libraries/VaultErrors.sol";
import {VaultEvents} from "../libraries/VaultEvents.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Vault is IVault, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event EmergencyResolved(address indexed admin);

    // =============================================================
    //                         STORAGE
    // =============================================================

    address public factory;
    address public underlying;
    address public emergencyCustodian;

    uint256 public totalAssets;
    uint256 public emergencyCustodiedAssets;
    mapping(address => uint256) public balances;

    bool public emergencyMode;
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
        if (emergencyMode) revert VaultErrors.EmergencyActive();
    }

    // =============================================================
    //                         CONSTRUCTOR
    // =============================================================

    constructor() {
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

        emit VaultEvents.VaultInitialized(underlying_, custodian_);
    }

    // =============================================================
    //                         VIEW HELPERS
    // =============================================================

    function managedAssets() public view returns (uint256) {
        return IERC20(underlying).balanceOf(address(this)) + emergencyCustodiedAssets;
    }

    function solvency() public view returns (bool) {
        return managedAssets() >= totalAssets;
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
        if (amount == 0) revert VaultErrors.InvalidAmount();

        IERC20 token = IERC20(underlying);

        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        uint256 balanceAfter = token.balanceOf(address(this));

        if (balanceAfter - balanceBefore != amount)
            revert VaultErrors.NonStandardERC20();

        balances[msg.sender] += amount;
        totalAssets += amount;

        emit VaultEvents.Deposit(msg.sender, amount);
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
        if (amount == 0) revert VaultErrors.InvalidAmount();

        uint256 userBalance = balances[msg.sender];
        if (userBalance < amount)
            revert VaultErrors.InsufficientBalance();

        IERC20 token = IERC20(underlying);

        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransfer(msg.sender, amount);
        uint256 balanceAfter = token.balanceOf(address(this));

        if (balanceBefore - balanceAfter != amount)
            revert VaultErrors.NonStandardERC20();

        balances[msg.sender] = userBalance - amount;
        totalAssets -= amount;

        emit VaultEvents.Withdraw(msg.sender, amount);
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
        if (emergencyMode)
            revert VaultErrors.EmergencyActive();

        emergencyMode = true;

        IERC20 token = IERC20(underlying);

        uint256 balanceBefore = token.balanceOf(address(this));
        uint256 custodianBalanceBefore =
            token.balanceOf(emergencyCustodian);

        if (balanceBefore > 0) {
            token.safeTransfer(emergencyCustodian, balanceBefore);

            uint256 balanceAfter =
                token.balanceOf(address(this));
            uint256 custodianBalanceAfter =
                token.balanceOf(emergencyCustodian);

            if (balanceBefore - balanceAfter != balanceBefore)
                revert VaultErrors.NonStandardERC20();

            if (custodianBalanceAfter - custodianBalanceBefore != balanceBefore)
                revert VaultErrors.NonStandardERC20();

            emergencyCustodiedAssets += balanceBefore;
        }

        emit VaultEvents.EmergencyActivated(msg.sender);
    }

    function resolveEmergency()
    external
    override
    onlyFactory
    nonReentrant
{
    if (!emergencyMode)
        revert VaultErrors.EmergencyNotActive();

    uint256 ec = emergencyCustodiedAssets;

    if (ec > 0) {
        uint256 currentBalance =
            IERC20(underlying).balanceOf(address(this));

        // Require that custody has been fully restored on-chain
        if (currentBalance < ec)
            revert VaultErrors.NotSolvent();

        // Reconcile emergency accounting
        emergencyCustodiedAssets = 0;
    }

    if (!solvency())
        revert VaultErrors.NotSolvent();

    emergencyMode = false;

    emit EmergencyResolved(msg.sender);
}

}