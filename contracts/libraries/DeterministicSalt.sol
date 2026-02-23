// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library DeterministicSalt {
    bytes32 internal constant SALT_DOMAIN = keccak256("DETERMINISTIC_VAULT_FACTORY_V1");

    function deriveSalt(
        address factory,
        address underlying,
        address admin,
        bytes32 userSalt
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                SALT_DOMAIN,
                block.chainid,
                factory,
                underlying,
                admin,
                userSalt
            )
        );
    }
}
