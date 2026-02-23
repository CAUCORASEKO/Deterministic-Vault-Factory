// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library VaultEvents {
    event VaultInitialized(address indexed underlying, address indexed admin);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyActivated(address indexed admin);
    event VaultCreated(address indexed vault, bytes32 indexed salt);
}
