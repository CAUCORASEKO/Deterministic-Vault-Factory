// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library VaultErrors {
    error NotFactory();
    error NotAdmin();
    error ZeroAddress();
    error AlreadyInitialized();
    error InvalidSalt();
    error NotSolvent();
    error NonStandardERC20();
    error UnderlyingNotSupported();
    error SaltAlreadyUsed();
    error VaultNotRegistered();
    error InvalidImplementation();

    // ===== NEW SEMANTIC ERRORS =====
    error InvalidAmount();
    error InsufficientBalance();
    error EmergencyActive();
    error EmergencyNotActive();
}