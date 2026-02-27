#!/usr/bin/env bash
set -euo pipefail

ENGINE_VERSION="1.1.0-deterministic-evidence"
SCHEMA_PATH="engine/schemas/project_input.schema.json"
TEMPLATE_PATH="engine/templates/institutional_report.md"
OUTPUT_DIR="engine/output"
FINAL_REPORT="${OUTPUT_DIR}/final_report.md"
CANONICAL_INPUT="${OUTPUT_DIR}/canonical_input.json"

# Hard determinism knobs
export LC_ALL=C
export TZ=UTC

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S')" "$1"
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

hash_file() {
  local file_path="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file_path" | awk '{print $1}'
    return
  fi

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file_path" | awk '{print $1}'
    return
  fi

  fail "Neither sha256sum nor shasum is available"
}

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'
}

json_get_required() {
  local input_file="$1"
  local query="$2"
  jq -er "$query" "$input_file"
}

validate_input_structure() {
  local input_file="$1"

  jq -e '
    type == "object" and
    (.project_name | type == "string" and length > 0) and
    (.version | type == "string" and length > 0) and
    (.network | type == "string" and length > 0) and
    (.governance | type == "object") and
    (.governance.multisig_address | type == "string" and test("^0x[a-fA-F0-9]{40}$")) and
    (.governance.threshold | type == "number" and . >= 1 and (floor == .)) and
    (.governance.timelock_enabled | type == "boolean") and
    (.economic_assumptions | type == "object") and
    (.economic_assumptions.tvl_usd | type == "number" and . >= 0) and
    (.economic_assumptions.liquidity_24h_pct | type == "number" and . >= 0 and . <= 100) and
    (.economic_assumptions.governance_latency_hours | type == "number" and . >= 0) and
    (.formal_model_present | type == "boolean") and
    (.spec_present | type == "boolean") and
    (.monitoring_defined | type == "boolean") and
    (.emergency_mechanism_defined | type == "boolean") and
    (.risk_acceptance_signed | type == "boolean")
  ' "$input_file" >/dev/null || fail "Input does not match required structure: $input_file"
}

# Canonicalize report for hashing by zeroing the embedded report hash line.
# This makes the report hash stable and verifiable.
canonical_report_hash() {
  local report_path="$1"
  local tmp
  tmp="$(mktemp)"

  # Replace any embedded 64-hex hash after the label with zeros (exactly 64 chars).
  # Pattern expects: Report Hash (SHA-256): `...`
  sed -E 's/(Report Hash \(SHA-256\): `)[a-f0-9]{64}(`)/\1000000000000000000000000000000000000000000000000000000000000000\2/g' \
    "$report_path" >"$tmp"

  local h
  h="$(hash_file "$tmp")"
  rm -f "$tmp"
  printf '%s' "$h"
}

run_agent() {
  local agent_name="$1"
  local input_file="$2"
  local out_file="${OUTPUT_DIR}/${agent_name}.md"

  # Token saver: if output exists, reuse it.
  if [[ -s "$out_file" ]]; then
    log "Reusing existing ${agent_name} output (token saver mode)"
    return
  fi

  log "Running ${agent_name}"
  codex exec --sandbox workspace-write "Run ${agent_name} on ${input_file}. Return deterministic markdown output only." >"${out_file}"
  log "Saved ${agent_name} output to ${out_file}"
}

# Extract policy decision values from decision_recommendation.json
extract_policy_values() {
  local decision_json="${OUTPUT_DIR}/decision_recommendation.json"

  [[ -s "$decision_json" ]] || fail "Decision file not found: $decision_json"

  # Extract values using jq
  local policy_recommended_decision policy_risk_class policy_escalation_required policy_flags policy_flags_str

  policy_recommended_decision="$(jq -r '.recommended_decision' "$decision_json")"
  policy_risk_class="$(jq -r '.risk_class' "$decision_json")"
  policy_escalation_required="$(jq -r '.escalation_required' "$decision_json" | tr '[:upper:]' '[:lower:]')"

  # Convert policy_flags array to deterministic string
  # If empty => "none", else => comma-separated list preserving JSON order
  policy_flags_str="$(jq -r '
    if .policy_flags == [] or .policy_flags == null then
      "none"
    else
      .policy_flags | join(", ")
    end
  ' "$decision_json")"

  # Also extract decision SHA-256 from the stored file
  local decision_sha256
  decision_sha256="$(cat "${OUTPUT_DIR}/decision_recommendation.json.sha256")"

  # Export for use in render function
  export POLICY_RECOMMENDED_DECISION="$policy_recommended_decision"
  export POLICY_RISK_CLASS="$policy_risk_class"
  export POLICY_ESCALATION_REQUIRED="$policy_escalation_required"
  export POLICY_FLAGS="$policy_flags_str"
  export DECISION_SHA256="$decision_sha256"
}

render_report_from_template() {
  local input_file="$1"
  local input_sha256="$2"
  local report_sha256="$3"
  local analysis_timestamp_utc="$4"
  local execution_environment="$5"
  shift 5
  local agents=("$@")

  local project_name project_version network multisig_address governance_threshold timelock_enabled
  local tvl_usd liquidity_24h_pct governance_latency_hours risk_acceptance_signed

  # Committee adjudication block (human sign-off, deterministic defaults)
  local committee_final_decision="PENDING COMMITTEE SIGN-OFF"
  local committee_decision_rationale="Policy engine output embedded; committee adjudication pending."
  local committee_override_flag="false"
  local committee_signatories="(to be completed by committee)"
  local committee_timestamp_utc="$analysis_timestamp_utc"

  project_name="$(json_get_required "$input_file" '.project_name')"
  project_version="$(json_get_required "$input_file" '.version')"
  network="$(json_get_required "$input_file" '.network')"
  multisig_address="$(json_get_required "$input_file" '.governance.multisig_address')"
  governance_threshold="$(json_get_required "$input_file" '.governance.threshold')"
  timelock_enabled="$(json_get_required "$input_file" '.governance.timelock_enabled')"
  tvl_usd="$(json_get_required "$input_file" '.economic_assumptions.tvl_usd')"
  liquidity_24h_pct="$(json_get_required "$input_file" '.economic_assumptions.liquidity_24h_pct')"
  governance_latency_hours="$(json_get_required "$input_file" '.economic_assumptions.governance_latency_hours')"
  risk_acceptance_signed="$(json_get_required "$input_file" '.risk_acceptance_signed')"

  # Policy decision values (exported from extract_policy_values)
  local policy_recommended_decision="${POLICY_RECOMMENDED_DECISION:-}"
  local policy_risk_class="${POLICY_RISK_CLASS:-}"
  local policy_escalation_required="${POLICY_ESCALATION_REQUIRED:-}"
  local policy_flags="${POLICY_FLAGS:-}"
  local decision_sha256="${DECISION_SHA256:-}"

  local structural_status="See Agent Evidence Appendix"
  local formal_status="See Agent Evidence Appendix"
  local economic_status="See Agent Evidence Appendix"
  local operational_status="See Agent Evidence Appendix"
  local final_decision="Pending Institutional Review"

  local structural_findings="Refer to appendix evidence from MASTER_REVIEW_AGENT and SPEC_COMPLIANCE_AGENT."
  local formal_findings="Refer to appendix evidence from FORMAL_MODEL_AGENT."
  local economic_findings="Refer to appendix evidence from RISK_CLASSIFICATION_AGENT."
  local operational_findings="Refer to appendix evidence from DEPLOYMENT_READINESS_AGENT."

  local scenario_a="Liquidity contraction stress (24h horizon)"
  local scenario_b="Governance execution delay under elevated volatility"
  local scenario_c="Emergency control activation and recovery sequencing"

  local risk_owner="Institutional Risk Committee"
  local risk_approval_timestamp_utc="$analysis_timestamp_utc"
  local risk_acceptance_notes="Formal acceptance status is sourced from provided project input."
  local final_decision_rationale="Deterministic evidence collected; final adjudication requires authorized sign-off."
  local conditions_precedent="Complete institutional approval workflow before deployment authorization."

  sed \
    -e "s|{{PROJECT_NAME}}|$(escape_sed_replacement "$project_name")|g" \
    -e "s|{{PROJECT_VERSION}}|$(escape_sed_replacement "$project_version")|g" \
    -e "s|{{NETWORK}}|$(escape_sed_replacement "$network")|g" \
    -e "s|{{MULTISIG_ADDRESS}}|$(escape_sed_replacement "$multisig_address")|g" \
    -e "s|{{GOVERNANCE_THRESHOLD}}|$(escape_sed_replacement "$governance_threshold")|g" \
    -e "s|{{TIMELOCK_ENABLED}}|$(escape_sed_replacement "$timelock_enabled")|g" \
    -e "s|{{TVL_USD}}|$(escape_sed_replacement "$tvl_usd")|g" \
    -e "s|{{LIQUIDITY_24H_PCT}}|$(escape_sed_replacement "$liquidity_24h_pct")|g" \
    -e "s|{{GOVERNANCE_LATENCY_HOURS}}|$(escape_sed_replacement "$governance_latency_hours")|g" \
    -e "s|{{STRUCTURAL_STATUS}}|$(escape_sed_replacement "$structural_status")|g" \
    -e "s|{{FORMAL_STATUS}}|$(escape_sed_replacement "$formal_status")|g" \
    -e "s|{{ECONOMIC_STATUS}}|$(escape_sed_replacement "$economic_status")|g" \
    -e "s|{{OPERATIONAL_STATUS}}|$(escape_sed_replacement "$operational_status")|g" \
    -e "s|{{FINAL_DECISION}}|$(escape_sed_replacement "$final_decision")|g" \
    -e "s|{{STRUCTURAL_FINDINGS}}|$(escape_sed_replacement "$structural_findings")|g" \
    -e "s|{{FORMAL_FINDINGS}}|$(escape_sed_replacement "$formal_findings")|g" \
    -e "s|{{ECONOMIC_FINDINGS}}|$(escape_sed_replacement "$economic_findings")|g" \
    -e "s|{{OPERATIONAL_FINDINGS}}|$(escape_sed_replacement "$operational_findings")|g" \
    -e "s|{{SCENARIO_A}}|$(escape_sed_replacement "$scenario_a")|g" \
    -e "s|{{SCENARIO_B}}|$(escape_sed_replacement "$scenario_b")|g" \
    -e "s|{{SCENARIO_C}}|$(escape_sed_replacement "$scenario_c")|g" \
    -e "s|{{POLICY_RECOMMENDED_DECISION}}|$(escape_sed_replacement "$policy_recommended_decision")|g" \
    -e "s|{{POLICY_RISK_CLASS}}|$(escape_sed_replacement "$policy_risk_class")|g" \
    -e "s|{{POLICY_ESCALATION_REQUIRED}}|$(escape_sed_replacement "$policy_escalation_required")|g" \
    -e "s|{{POLICY_FLAGS}}|$(escape_sed_replacement "$policy_flags")|g" \
    -e "s|{{DECISION_SHA256}}|$(escape_sed_replacement "$decision_sha256")|g" \
    -e "s|{{RISK_ACCEPTANCE_SIGNED}}|$(escape_sed_replacement "$risk_acceptance_signed")|g" \
    -e "s|{{RISK_OWNER}}|$(escape_sed_replacement "$risk_owner")|g" \
    -e "s|{{RISK_APPROVAL_TIMESTAMP_UTC}}|$(escape_sed_replacement "$risk_approval_timestamp_utc")|g" \
    -e "s|{{RISK_ACCEPTANCE_NOTES}}|$(escape_sed_replacement "$risk_acceptance_notes")|g" \
    -e "s|{{FINAL_DECISION_RATIONALE}}|$(escape_sed_replacement "$final_decision_rationale")|g" \
    -e "s|{{CONDITIONS_PRECEDENT}}|$(escape_sed_replacement "$conditions_precedent")|g" \
    -e "s|{{ENGINE_VERSION}}|$(escape_sed_replacement "$ENGINE_VERSION")|g" \
    -e "s|{{INPUT_SHA256}}|$(escape_sed_replacement "$input_sha256")|g" \
    -e "s|{{REPORT_SHA256}}|$(escape_sed_replacement "$report_sha256")|g" \
    -e "s|{{ANALYSIS_TIMESTAMP_UTC}}|$(escape_sed_replacement "$analysis_timestamp_utc")|g" \
    -e "s|{{EXECUTION_ENVIRONMENT}}|$(escape_sed_replacement "$execution_environment")|g" \
    -e "s|{{COMMITTEE_FINAL_DECISION}}|$(escape_sed_replacement "$committee_final_decision")|g" \
    -e "s|{{COMMITTEE_DECISION_RATIONALE}}|$(escape_sed_replacement "$committee_decision_rationale")|g" \
    -e "s|{{COMMITTEE_OVERRIDE_FLAG}}|$(escape_sed_replacement "$committee_override_flag")|g" \
    -e "s|{{COMMITTEE_SIGNATORIES}}|$(escape_sed_replacement "$committee_signatories")|g" \
    -e "s|{{COMMITTEE_TIMESTAMP_UTC}}|$(escape_sed_replacement "$committee_timestamp_utc")|g" \
    "$TEMPLATE_PATH" >"$FINAL_REPORT"

  printf '\n## Agent Evidence Appendix\n\n' >>"$FINAL_REPORT"
  local agent
  for agent in "${agents[@]}"; do
    printf '### %s\n\n' "$agent" >>"$FINAL_REPORT"
    cat "${OUTPUT_DIR}/${agent}.md" >>"$FINAL_REPORT"
    printf '\n\n' >>"$FINAL_REPORT"
  done
}

main() {
  local input_file="${1:-}"

  [[ -n "$input_file" ]] || fail "Usage: $0 <project-input.json>"
  [[ -f "$input_file" ]] || fail "Input file not found: $input_file"
  [[ -f "$SCHEMA_PATH" ]] || fail "Schema file not found: $SCHEMA_PATH"
  [[ -f "$TEMPLATE_PATH" ]] || fail "Template file not found: $TEMPLATE_PATH"

  require_command jq
  require_command uname
  require_command python3

  log "Validating input structure"
  validate_input_structure "$input_file"

  mkdir -p "$OUTPUT_DIR"

  # Canonical input for deterministic hashing
  jq -S . "$input_file" >"$CANONICAL_INPUT"
  local input_sha256
  input_sha256="$(hash_file "$CANONICAL_INPUT")"

  # Timestamp logic: audit_mode => require deterministic timestamp in input
  local analysis_timestamp_utc
  if jq -e '.audit_mode == true' "$input_file" >/dev/null 2>&1; then
    analysis_timestamp_utc="$(jq -r '.analysis_timestamp_utc // empty' "$input_file")"
    [[ -n "$analysis_timestamp_utc" ]] || fail "audit_mode=true requires analysis_timestamp_utc in input"
    log "Audit mode enabled with deterministic timestamp"
  else
    analysis_timestamp_utc="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  fi

  local execution_environment
  execution_environment="$(uname -a)"

  log "Input hash computed: ${input_sha256}"

  local agents=(
    "MASTER_REVIEW_AGENT"
    "SPEC_COMPLIANCE_AGENT"
    "FORMAL_MODEL_AGENT"
    "RISK_CLASSIFICATION_AGENT"
    "DEPLOYMENT_READINESS_AGENT"
  )

  # If codex isn't available or you're out of credits, you can prefill outputs.
  if command -v codex >/dev/null 2>&1; then
    for agent in "${agents[@]}"; do
      run_agent "$agent" "$input_file"
    done
  else
    log "codex not found; expecting agent outputs already present in ${OUTPUT_DIR}"
  fi

  # ---- Policy Decision Layer (Deterministic) ----
  local decision_json decision_sha_file decision_sha
  decision_json="${OUTPUT_DIR}/decision_recommendation.json"
  decision_sha_file="${OUTPUT_DIR}/decision_recommendation.json.sha256"

  log "Running policy decision engine"
  python3 engine/policy/decision_engine.py "$CANONICAL_INPUT" >/dev/null 2>&1 || fail "Policy engine failed"

  [[ -s "$decision_json" ]] || fail "Decision file not created: $decision_json"

  decision_sha="$(hash_file "$decision_json")"
  printf '%s\n' "$decision_sha" >"$decision_sha_file"

  log "Policy decision generated"
  log "Decision SHA-256: ${decision_sha}"

  # Extract policy values for template rendering
  extract_policy_values

  # Phase 1: render with report hash = zeros
  local zeros
  zeros="0000000000000000000000000000000000000000000000000000000000000000"

  render_report_from_template \
    "$input_file" \
    "$input_sha256" \
    "$zeros" \
    "$analysis_timestamp_utc" \
    "$execution_environment" \
    "${agents[@]}"

  # Phase 2: compute canonical report hash (with report hash line zeroed) and embed it
  local report_sha256
  report_sha256="$(canonical_report_hash "$FINAL_REPORT")"

  render_report_from_template \
    "$input_file" \
    "$input_sha256" \
    "$report_sha256" \
    "$analysis_timestamp_utc" \
    "$execution_environment" \
    "${agents[@]}"

  # ---- Summary ----
  log "Final report written to ${FINAL_REPORT}"
  printf 'Engine version: %s\n' "$ENGINE_VERSION"
  printf 'Input hash: %s\n' "$input_sha256"
  printf 'Report hash (canonical): %s\n' "$report_sha256"
  printf 'Decision hash: %s\n' "$decision_sha"
  printf 'Timestamp (UTC): %s\n' "$analysis_timestamp_utc"

  # ---- Deterministic Evidence Vault Archive ----
  [[ -s "$FINAL_REPORT" ]] || fail "Cannot archive evidence: required artifact missing"
  [[ -s "$decision_json" ]] || fail "Cannot archive evidence: required artifact missing"
  [[ -s "$decision_sha_file" ]] || fail "Cannot archive evidence: required artifact missing"

  local vault_dir
  vault_dir="vault/${input_sha256}"
  mkdir -p "$vault_dir"

  cp "$CANONICAL_INPUT" "$vault_dir/"
  cp "$FINAL_REPORT" "$vault_dir/"
  cp "$decision_json" "$vault_dir/"
  cp "$decision_sha_file" "$vault_dir/"

  log "Evidence archived to vault/${input_sha256}"
}

main "$@"
