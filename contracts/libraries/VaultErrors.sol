// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library VaultErrors {
    error NotFactory();
    error NotAdmin();
    error ZeroAddress();
    error AlreadyInitialized();
    error InvalidSalt();
    error NotSolvent();
}
