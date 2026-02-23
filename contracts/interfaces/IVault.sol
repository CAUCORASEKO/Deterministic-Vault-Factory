// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IVault {
    // Mirrored canonical event signatures from VaultEvents.
    event VaultInitialized(address indexed underlying, address indexed admin);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyActivated(address indexed admin);

    function initialize(address underlying_, address admin_) external;

    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function emergencyWithdraw() external;
}
