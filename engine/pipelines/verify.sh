#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="engine/output"
CANONICAL_INPUT="${OUTPUT_DIR}/canonical_input.json"
FINAL_REPORT="${OUTPUT_DIR}/final_report.md"
DECISION_JSON="${OUTPUT_DIR}/decision_recommendation.json"
DECISION_SHA_FILE="${OUTPUT_DIR}/decision_recommendation.json.sha256"

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "Missing required file: $1"
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

# Canonicalize report for hashing by zeroing the embedded report hash line.
canonical_report_hash() {
  local report_path="$1"
  local tmp
  tmp="$(mktemp)"

  sed -E 's/(Report Hash \(SHA-256\): `)[a-f0-9]{64}(`)/\1000000000000000000000000000000000000000000000000000000000000000\2/g' \
    "$report_path" >"$tmp"

  local h
  h="$(hash_file "$tmp")"
  rm -f "$tmp"
  printf '%s' "$h"
}

extract_report_hash_from_report() {
  grep -Eo 'Report Hash \(SHA-256\): `([a-f0-9]{64})`' "$FINAL_REPORT" 2>/dev/null \
    | head -n1 \
    | grep -Eo '[a-f0-9]{64}' || true
}

extract_input_hash_from_report() {
  grep -Eo 'Input Hash \(SHA-256\): `([a-f0-9]{64})`' "$FINAL_REPORT" 2>/dev/null \
    | head -n1 \
    | grep -Eo '[a-f0-9]{64}' || true
}

main() {
  require_file "$CANONICAL_INPUT"
  require_file "$FINAL_REPORT"

  local computed_input_hash computed_report_hash embedded_input_hash embedded_report_hash

  computed_input_hash="$(hash_file "$CANONICAL_INPUT")"
  computed_report_hash="$(canonical_report_hash "$FINAL_REPORT")"

  embedded_input_hash="$(extract_input_hash_from_report)"
  embedded_report_hash="$(extract_report_hash_from_report)"

  printf 'Computed Input SHA-256             : %s\n' "$computed_input_hash"
  printf 'Computed Report SHA-256 (canonical): %s\n' "$computed_report_hash"

  if [[ -n "$embedded_input_hash" ]]; then
    printf 'Embedded Input SHA-256             : %s\n' "$embedded_input_hash"
    [[ "$embedded_input_hash" == "$computed_input_hash" ]] || fail "Input hash mismatch"
  fi

  if [[ -n "$embedded_report_hash" ]]; then
    printf 'Embedded Report SHA-256 (canonical): %s\n' "$embedded_report_hash"
    [[ "$embedded_report_hash" == "$computed_report_hash" ]] || fail "Report hash mismatch"
  fi

  printf 'VERIFY: PASS\n'

  # --- Decision verification (optional but bank-grade) ---
  if [[ -f "$DECISION_JSON" || -f "$DECISION_SHA_FILE" ]]; then
    require_file "$DECISION_JSON"
    require_file "$DECISION_SHA_FILE"

    local computed_decision_hash expected_decision_hash
    computed_decision_hash="$(hash_file "$DECISION_JSON")"
    expected_decision_hash="$(awk '{print $1}' "$DECISION_SHA_FILE")"

    printf 'Computed Decision SHA-256          : %s\n' "$computed_decision_hash"
    printf 'Expected Decision SHA-256          : %s\n' "$expected_decision_hash"
    [[ "$computed_decision_hash" == "$expected_decision_hash" ]] || fail "Decision hash mismatch"
    printf 'VERIFY DECISION: PASS\n'
  else
    printf 'VERIFY DECISION: SKIP (no decision artifacts)\n'
  fi
}

main "$@"