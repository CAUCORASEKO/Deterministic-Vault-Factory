// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IVaultFactory {
    event VaultCreated(address indexed vault, bytes32 indexed salt);

    function createVault(address underlying, address admin, bytes32 userSalt) external returns (address vault);

    function predictVaultAddress(address underlying, address admin, bytes32 userSalt) external view returns (address predicted);

    function triggerEmergency(address vault) external;
}
