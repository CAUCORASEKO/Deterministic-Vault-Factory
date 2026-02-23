FORMAL MODEL CONFORMANCE REPORT

Model Version:
UNSPECIFIED (no standalone formal model file found in scope); working equation set extracted from repository-defined invariants I1–I6 and deterministic salt policy artifacts.

Code Baseline:
`f3c659e` (working tree with uncommitted changes)

Overall Mathematical Conformance:
PARTIALLY CONFORMANT

Equation Coverage Summary:
- Total equations: 9
- Satisfied: 7
- Violated: 2
- Partial: 0
- Not applicable: 0

Critical Equation Failures:
- None.

High-Risk Equation Gaps:
- E8 Canonical deterministic salt equation mismatch between `contracts/core/VaultFactory.sol:122` and `contracts/libraries/DeterministicSalt.sol:9`.
- E9 Emergency transition realizability gap: model transition exists, but scoped system has no callable factory forwarding path (`contracts/core/Vault.sol:156`, `contracts/core/VaultFactory.sol:44`).

Equation Matrix:

[E1]
- Formal Equation: `totalAssets(t) = Σ_u balances[u](t)`
- Variable Mapping: `totalAssets -> Vault.totalAssets`; `balances[u] -> Vault.balances[user]`
- Transition Context: `deposit`, `withdraw`, `emergencyWithdraw`, `initialize`
- State Definition: `S(t) = {totalAssets, balances[*], emergencyCustodiedAssets, onChainBalance, emergencyMode, _initialized}`
- Expected Delta Relationship: `ΔtotalAssets = Σ_u Δbalances[u]`
- Observed Code Behavior: Deposit updates both by `+received` (`contracts/core/Vault.sol:111`, `contracts/core/Vault.sol:112`); withdraw updates both by `-amount` (`contracts/core/Vault.sol:132`, `contracts/core/Vault.sol:133`); emergency leaves both unchanged (`contracts/core/Vault.sol:161` to `contracts/core/Vault.sol:178`).
- Status: SATISFIED
- Violation Type: Structural
- Severity: INFO
- Impact: Liability conservation holds across implemented transitions.
- Remediation Direction: Keep as invariant property test.

[E2]
- Formal Equation: `managedAssets(t) = onChainBalance(t) + emergencyCustodiedAssets(t)`
- Variable Mapping: `managedAssets -> Vault.managedAssets()`; `onChainBalance -> IERC20(underlying).balanceOf(this)`; `emergencyCustodiedAssets -> Vault.emergencyCustodiedAssets`
- Transition Context: Global
- State Definition: `S(t)` as above
- Expected Delta Relationship: `ΔmanagedAssets = ΔonChainBalance + ΔemergencyCustodiedAssets`
- Observed Code Behavior: Exact implementation in `contracts/core/Vault.sol:141` to `contracts/core/Vault.sol:143`.
- Status: SATISFIED
- Violation Type: Structural
- Severity: INFO
- Impact: Managed custody is consistently defined.
- Remediation Direction: None.

[E3]
- Formal Equation: `solvency(t) := managedAssets(t) >= totalAssets(t)`
- Variable Mapping: `solvency -> Vault.solvency()`
- Transition Context: Global
- State Definition: `S(t)` as above
- Expected Delta Relationship: Solvency predicate computed from E1/E2 variables
- Observed Code Behavior: Exact implementation in `contracts/core/Vault.sol:145` to `contracts/core/Vault.sol:147`.
- Status: SATISFIED
- Violation Type: Structural
- Severity: INFO
- Impact: Solvency check equation is correctly encoded.
- Remediation Direction: None.

[E4]
- Formal Equation: Deposit transition `S(t)->S(t+1)` with `Δbalances[user]=a`, `ΔtotalAssets=a`, `ΔmanagedAssets=a`, `a>0`
- Variable Mapping: `a -> received`
- Transition Context: `deposit`
- State Definition: `S(t)` and post-state after `deposit(amount)`
- Expected Delta Relationship: `ΔtotalAssets = Δbalances[user] = ΔmanagedAssets`
- Observed Code Behavior: Balance-delta accounting (`contracts/core/Vault.sol:100` to `contracts/core/Vault.sol:109`) then equal increments (`contracts/core/Vault.sol:111`, `contracts/core/Vault.sol:112`).
- Status: SATISFIED
- Violation Type: Numerical
- Severity: INFO
- Impact: Positive liability change is custody-backed.
- Remediation Direction: None.

[E5]
- Formal Equation: Withdraw transition `S(t)->S(t+1)` with `Δbalances[user]=-a`, `ΔtotalAssets=-a`, `ΔmanagedAssets=-a`, `a>0`
- Variable Mapping: `a -> amount`
- Transition Context: `withdraw`
- State Definition: `S(t)` and post-state after `withdraw(amount)`
- Expected Delta Relationship: Liability and managed custody decrease equally
- Observed Code Behavior: Preconditions and decrements (`contracts/core/Vault.sol:127` to `contracts/core/Vault.sol:133`) then transfer out (`contracts/core/Vault.sol:135`).
- Status: SATISFIED
- Violation Type: Numerical
- Severity: INFO
- Impact: Withdrawal accounting preserves conservation.
- Remediation Direction: None.

[E6]
- Formal Equation: Emergency neutrality transition `S(t)->S(t+1)` with `ΔtotalAssets=0`, `Δbalances[*]=0`, `ΔonChainBalance=-b`, `ΔemergencyCustodiedAssets=+b`, hence `ΔmanagedAssets=0`
- Variable Mapping: `b -> token.balanceOf(this)` at emergency activation
- Transition Context: `emergencyWithdraw`
- State Definition: `S(t)` before and after emergency migration
- Expected Delta Relationship: Custody location changes without liability mutation
- Observed Code Behavior: Sets emergency mode (`contracts/core/Vault.sol:161`), increments emergency custody by full balance (`contracts/core/Vault.sol:167`), transfers same amount out (`contracts/core/Vault.sol:169` to `contracts/core/Vault.sol:172`), leaves liabilities untouched.
- Status: SATISFIED
- Violation Type: Structural
- Severity: INFO
- Impact: Emergency migration is mathematically neutral on liabilities.
- Remediation Direction: None.

[E7]
- Formal Equation: Initialization safety `initialized(t)=false -> initialized(t+1)=true`, and no second successful initialization
- Variable Mapping: `initialized -> Vault._initialized`
- Transition Context: `initialize`
- State Definition: `S(t)` for implementation and clone instance
- Expected Delta Relationship: One-way boolean transition; single execution
- Observed Code Behavior: Implementation locked in constructor (`contracts/core/Vault.sol:59` to `contracts/core/Vault.sol:62`); `initialize` reverts if already initialized and sets true once (`contracts/core/Vault.sol:73`, `contracts/core/Vault.sol:81`).
- Status: SATISFIED
- Violation Type: Structural
- Severity: INFO
- Impact: Prevents reinitialization drift.
- Remediation Direction: None.

[E8]
- Formal Equation: Canonical deterministic salt must be a single function `finalSalt = H(domain, identity_tuple)`
- Variable Mapping: `finalSalt -> VaultFactory._deriveSalt / DeterministicSalt.deriveSalt`
- Transition Context: `createVault`, `predictVaultAddress`
- State Definition: `S(t)` includes deterministic identity policy
- Expected Delta Relationship: Same inputs under canonical policy map to one salt function
- Observed Code Behavior: Factory uses `H(domain, chainid, factory, implementation, underlying, custodian, userSalt)` (`contracts/core/VaultFactory.sol:122` to `contracts/core/VaultFactory.sol:131`), but library uses `H(domain, underlying, admin, userSalt)` and is marked TODO (`contracts/libraries/DeterministicSalt.sol:7` to `contracts/libraries/DeterministicSalt.sol:9`).
- Status: VIOLATED
- Violation Type: Structural
- Severity: HIGH
- Impact: Deterministic identity model can drift across integrations/future call paths.
- Remediation Direction: Enforce one canonical salt equation and remove/align divergent implementation.

[E9]
- Formal Equation: Emergency transition in model must be realizable in system-level state graph
- Variable Mapping: `emergencyWithdraw transition -> Vault.emergencyWithdraw callable path`
- Transition Context: `emergencyWithdraw`
- State Definition: `S(t)` at protocol level (factory + vault)
- Expected Delta Relationship: There exists an authorized path executing emergency transition
- Observed Code Behavior: Vault requires `onlyFactory` (`contracts/core/Vault.sol:156`), but scoped factory exposes no method invoking vault emergency (`contracts/core/VaultFactory.sol:44` to `contracts/core/VaultFactory.sol:87`).
- Status: VIOLATED
- Violation Type: Structural
- Severity: HIGH
- Impact: Formal transition exists mathematically but is not reachable through scoped protocol interface.
- Remediation Direction: Add explicit factory emergency-forward transition or revise authorization model.

Invariant Verification:
- I1 Liability Conservation: PASS
- I2 Solvency: PASS
- I3 No Stored Surplus: PASS
- I4 No-liability-without-custody-delta: PASS
- I5 Emergency Neutrality: PASS
- I6 Initialization Safety: PASS

State Space Soundness:
- Non-negativity preserved: YES
- Overflow safety preserved: YES
- Monotonicity constraints respected: YES
- Non-interference validated: YES
- Composition closure verified: NO

Transition Proof Status:
- deposit(): VERIFIED
- withdraw(): VERIFIED
- emergencyWithdraw(): PARTIAL
- initialize(): VERIFIED

Final Verdict:
REQUIRES FORMAL CORRECTION

End of Report.
