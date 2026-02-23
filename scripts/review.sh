#!/usr/bin/env bash
set -e

mkdir -p reports
rm -f reports/master.md reports/spec.md reports/formal.md reports/risk.md reports/readiness.md

SCOPE="contracts/core/Vault.sol contracts/core/VaultFactory.sol contracts/libraries/DeterministicSalt.sol"

echo "Running MASTER_REVIEW_AGENT..."
codex exec "Use agents/MASTER_REVIEW_AGENT.md.
Scope:
$SCOPE
Follow strict output format.
Return only the MASTER PROTOCOL REVIEW REPORT." \
> reports/master.md

echo "Running SPEC_COMPLIANCE_AGENT..."
codex exec "Use agents/SPEC_COMPLIANCE_AGENT.md.
Scope:
$SCOPE
Formal specification source:
docs/spec_v1.md
Follow strict output format.
Return only the SPEC COMPLIANCE REPORT." \
> reports/spec.md

echo "Running FORMAL_MODEL_AGENT..."
codex exec "Use agents/FORMAL_MODEL_AGENT.md.
Scope:
$SCOPE
Formal mathematical model source:
docs/formal_model_v1.md
Follow strict output format.
Return only the FORMAL MODEL CONFORMANCE REPORT." \
> reports/formal.md

echo "Running RISK_CLASSIFICATION_AGENT..."
codex exec "Use agents/RISK_CLASSIFICATION_AGENT.md.
Use findings from reports/master.md, reports/spec.md, reports/formal.md.
Follow strict output format.
Return only the ECONOMIC RISK CLASSIFICATION REPORT." \
> reports/risk.md

echo "Running DEPLOYMENT_READINESS_AGENT..."
codex exec "Use agents/DEPLOYMENT_READINESS_AGENT.md.
Use only these source reports:
- reports/master.md
- reports/spec.md
- reports/formal.md
- reports/risk.md
Operational release context source:
docs/deployment_context_v1.md
Follow strict output format.
Return only the DEPLOYMENT READINESS DECISION REPORT." \
> reports/readiness.md

echo "Review complete."
