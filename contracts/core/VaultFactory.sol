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
    mapping(address => bool) public supportedUnderlying;

    // =============================================================
    //                         EVENTS
    // =============================================================

    event UnderlyingSupportUpdated(address indexed underlying, bool supported);

    // =============================================================
    //                         MODIFIERS
    // =============================================================

    modifier onlyGovernance() {
        _onlyGovernance();
        _;
    }

    function _onlyGovernance() internal view {
        if (msg.sender != GOVERNANCE) revert VaultErrors.NotAdmin();
    }

    // =============================================================
    //                         CONSTRUCTOR
    // =============================================================

    constructor(address vaultImplementation_, address governance_) {
        if (vaultImplementation_ == address(0) || governance_ == address(0))
            revert VaultErrors.ZeroAddress();

        if (vaultImplementation_.code.length == 0)
            revert VaultErrors.InvalidImplementation();

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

        if (!supportedUnderlying[underlying])
            revert VaultErrors.UnderlyingNotSupported();

        bytes32 finalSalt = DeterministicSalt.deriveSalt(
            address(this),
            underlying,
            custodian,
            userSalt
        );

        if (vaultBySalt[finalSalt] != address(0))
            revert VaultErrors.SaltAlreadyUsed();

        address implementation = VAULT_IMPLEMENTATION;

        address predicted = Clones.predictDeterministicAddress(
            implementation,
            finalSalt,
            address(this)
        );

        if (predicted.code.length != 0)
            revert VaultErrors.SaltAlreadyUsed();

        vault = Clones.cloneDeterministic(
            implementation,
            finalSalt
        );

        IVault(vault).initialize(underlying, custodian);

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

    // =============================================================
    //                     EMERGENCY CONTROL
    // =============================================================

    function triggerEmergency(address vault)
        external
        override
        onlyGovernance
    {
        if (!isVault[vault])
            revert VaultErrors.VaultNotRegistered();

        IVault(vault).emergencyWithdraw();
    }

    function resolveEmergency(address vault)
        external
        override
        onlyGovernance
    {
        if (!isVault[vault])
            revert VaultErrors.VaultNotRegistered();

        IVault(vault).resolveEmergency();
    }

    // =============================================================
    //                     UNDERLYING CONTROL
    // =============================================================

    function setSupportedUnderlying(
        address underlying,
        bool supported
    ) external override onlyGovernance {
        if (underlying == address(0))
            revert VaultErrors.ZeroAddress();

        supportedUnderlying[underlying] = supported;

        emit UnderlyingSupportUpdated(underlying, supported);
    }
}