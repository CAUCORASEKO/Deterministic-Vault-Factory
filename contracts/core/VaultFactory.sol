// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVaultFactory} from "../interfaces/IVaultFactory.sol";
import {IVault} from "../interfaces/IVault.sol";
import {VaultErrors} from "../libraries/VaultErrors.sol";
import {VaultEvents} from "../libraries/VaultEvents.sol";
import {DeterministicSalt} from "../libraries/DeterministicSalt.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract VaultFactory is IVaultFactory {
    using Clones for address;

    // =============================================================
    //                         STORAGE
    // =============================================================

    address public immutable GOVERNANCE;
    address public immutable VAULT_IMPLEMENTATION;

    mapping(bytes32 => address) public vaultBySalt;
    mapping(address => bool) public isVault;

    // =============================================================
    //                         CONSTRUCTOR
    // =============================================================

    modifier onlyGovernance() {
        if (msg.sender != GOVERNANCE) revert VaultErrors.NotAdmin();
        _;
    }

    constructor(address vaultImplementation_, address governance_) {
        if (vaultImplementation_ == address(0) || governance_ == address(0))
            revert VaultErrors.ZeroAddress();

        GOVERNANCE = governance_;
        VAULT_IMPLEMENTATION = vaultImplementation_;
    }

    // =============================================================
    //                         CREATE VAULT
    // =============================================================

    function createVault(
        address underlying,
        address custodian,
        bytes32 userSalt
    ) external override returns (address vault) {

        if (underlying == address(0) || custodian == address(0))
            revert VaultErrors.ZeroAddress();

        bytes32 finalSalt = DeterministicSalt.deriveSalt(
            address(this),
            underlying,
            custodian,
            userSalt
        );

        if (vaultBySalt[finalSalt] != address(0))
            revert VaultErrors.InvalidSalt();

        // Predict address first
        address predicted = Clones.predictDeterministicAddress(
            VAULT_IMPLEMENTATION,
            finalSalt,
            address(this)
        );

        // Ensure no contract already exists at predicted address
        if (predicted.code.length != 0)
            revert VaultErrors.InvalidSalt();

        // Deploy clone deterministically
        vault = Clones.cloneDeterministic(
            VAULT_IMPLEMENTATION,
            finalSalt
        );

        // Initialize atomically
        IVault(vault).initialize(underlying, custodian);

        // Registry updates
        vaultBySalt[finalSalt] = vault;
        isVault[vault] = true;

        emit VaultEvents.VaultCreated(vault, finalSalt);
    }

    // =============================================================
    //                         PREDICT
    // =============================================================

    function predictVaultAddress(
        address underlying,
        address custodian,
        bytes32 userSalt
    ) external view override returns (address predicted) {

        bytes32 finalSalt = DeterministicSalt.deriveSalt(
            address(this),
            underlying,
            custodian,
            userSalt
        );

        predicted = Clones.predictDeterministicAddress(
            VAULT_IMPLEMENTATION,
            finalSalt,
            address(this)
        );
    }

    function triggerEmergency(address vault) external override onlyGovernance {
        if (!isVault[vault]) revert VaultErrors.InvalidSalt();
        IVault(vault).emergencyWithdraw();
    }
}
