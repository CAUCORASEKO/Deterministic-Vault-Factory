#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C
export TZ=UTC

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S')" "$1"
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

usage() {
  printf 'Usage: %s <path_to_zip>\n' "$0" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

# --- SAFE CLEANUP ---
tmp_dir=""

cleanup() {
  if [[ -n "${tmp_dir:-}" && -d "${tmp_dir:-}" ]]; then
    rm -rf "$tmp_dir"
  fi
}
trap cleanup EXIT

main() {
  [[ $# -eq 1 ]] || usage
  local zip_path="$1"

  require_command unzip
  require_command shasum
  require_command python3

  [[ -f "$zip_path" ]] || fail "Package ZIP not found: $zip_path"

  tmp_dir="$(mktemp -d)"

  log "Extracting package"
  unzip -q "$zip_path" -d "$tmp_dir"

  local package_root="${tmp_dir}/package_v1"
  local manifest_path="${package_root}/manifest.json"
  local sums_path="${package_root}/SHA256SUMS"

  [[ -f "$manifest_path" ]] || fail "Missing required file: package_v1/manifest.json"
  [[ -f "$sums_path" ]] || fail "Missing required file: package_v1/SHA256SUMS"

  log "Verifying SHA256SUMS"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue

    case "$line" in
      *"  "*)
        ;;
      *)
        fail "Malformed SHA256SUMS line: $line"
        ;;
    esac

    local expected_hash rel_path actual_hash
    expected_hash="${line%%  *}"
    rel_path="${line#*  }"

    [[ -n "$expected_hash" ]] || fail "Empty hash in SHA256SUMS"
    [[ -n "$rel_path" ]] || fail "Empty path in SHA256SUMS"

    local target="${package_root}/${rel_path}"
    [[ -f "$target" ]] || fail "Listed file missing: ${rel_path}"

    actual_hash="$(shasum -a 256 "$target" | awk '{print $1}')"
    [[ "$actual_hash" == "$expected_hash" ]] || fail "Hash mismatch for ${rel_path}"
  done <"$sums_path"

  local input_sha256
  input_sha256="$(python3 - "$manifest_path" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)
print(data.get("input_sha256", ""))
PY
)"

  printf 'input_sha256: %s\n' "$input_sha256"
  printf 'VERIFY PACKAGE: PASS\n'
}

main "$@"