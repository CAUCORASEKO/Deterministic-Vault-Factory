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
  printf 'Usage: %s <input_sha256>\n' "$0" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

first_token() {
  awk '{print $1; exit}' "$1"
}

extract_report_hash() {
  local report_path="$1"
  python3 - "$report_path" <<'PY'
import re
import sys

path = sys.argv[1]
pattern = re.compile(r"Report Hash \(SHA-256\): `([A-Fa-f0-9]{64})`")
result = ""
with open(path, "r", encoding="utf-8") as f:
    for line in f:
        m = pattern.search(line)
        if m:
            result = m.group(1).lower()
            break
print(result)
PY
}

read_timestamp_or_now() {
  local canonical_input="$1"
  python3 - "$canonical_input" <<'PY'
import json
import sys
from datetime import datetime, timezone

path = sys.argv[1]
value = None
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    raw = data.get("analysis_timestamp_utc")
    if isinstance(raw, str) and raw.strip():
        parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        value = parsed.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
except Exception:
    value = None

if value is None:
    value = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

print(value)
PY
}

write_manifest() {
  local package_root="$1"
  local input_sha256="$2"
  local package_timestamp="$3"
  local report_sha256_canonical="$4"
  local decision_sha256="$5"

  python3 - "$package_root" "$input_sha256" "$package_timestamp" "$report_sha256_canonical" "$decision_sha256" <<'PY'
import json
import os
import subprocess
import sys

package_root, input_sha256, package_timestamp, report_sha256_canonical, decision_sha256 = sys.argv[1:6]

def tool_version(cmd):
    try:
        p = subprocess.run([cmd, "--version"], capture_output=True, text=True, check=False)
        out = (p.stdout or p.stderr or "").strip().splitlines()
        if p.returncode == 0 and out:
            return out[0].strip()
    except Exception:
        pass
    return "unknown"

included_files = []
for root, _, files in os.walk(package_root):
    for name in files:
        rel = os.path.relpath(os.path.join(root, name), package_root)
        rel = rel.replace(os.sep, "/")
        if rel in ("manifest.json", "SHA256SUMS"):
            continue
        included_files.append(rel)
included_files.sort()

manifest = {
    "decision_sha256": decision_sha256,
    "included_files": included_files,
    "input_sha256": input_sha256,
    "package_build_timestamp_utc": package_timestamp,
    "package_version": "1.0",
    "report_sha256_canonical": report_sha256_canonical,
    "tool_versions": {
        "python3": tool_version("python3"),
        "shasum": tool_version("shasum"),
        "zip": tool_version("zip"),
    },
}

manifest_path = os.path.join(package_root, "manifest.json")
with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2, sort_keys=True)
    f.write("\n")
PY
}

normalize_mtimes() {
  local package_root="$1"
  local package_timestamp="$2"

  python3 - "$package_root" "$package_timestamp" <<'PY'
import os
import sys
from datetime import datetime, timezone

package_root, ts = sys.argv[1], sys.argv[2]
try:
    dt = datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone(timezone.utc)
except ValueError as exc:
    raise SystemExit(f"Invalid timestamp for mtime normalization: {ts}") from exc
epoch = dt.timestamp()

for root, dirs, files in os.walk(package_root):
    for name in files:
        path = os.path.join(root, name)
        os.utime(path, (epoch, epoch))
    for name in dirs:
        path = os.path.join(root, name)
        os.utime(path, (epoch, epoch))

os.utime(package_root, (epoch, epoch))
PY
}

build_sha256sums() {
  local package_root="$1"
  local tmp_file="${package_root}/.SHA256SUMS.tmp"
  : >"$tmp_file"

  # IMPORTANT: exclude tmp file (and SHA256SUMS/manifest) from the list we hash.
  while IFS= read -r rel; do
    [[ "$rel" == "SHA256SUMS" ]] && continue
    [[ "$rel" == ".SHA256SUMS.tmp" ]] && continue
    [[ "$rel" == "manifest.json" ]] && continue

    local h
    h="$(shasum -a 256 "$package_root/$rel" | awk '{print $1}')"
    printf '%s  %s\n' "$h" "$rel" >>"$tmp_file"
  done < <(
    find "$package_root" -type f \
      ! -name 'SHA256SUMS' \
      ! -name '.SHA256SUMS.tmp' \
      ! -name 'manifest.json' \
      | sed "s|^${package_root}/||" \
      | LC_ALL=C sort
  )

  LC_ALL=C sort -k2,2 "$tmp_file" >"${package_root}/SHA256SUMS"
  rm -f "$tmp_file"
}

main() {
  [[ $# -eq 1 ]] || usage
  local input_sha256="$1"

  require_command python3
  require_command shasum
  require_command zip

  local vault_dir="vault/${input_sha256}"
  [[ -d "$vault_dir" ]] || fail "Vault entry not found: ${vault_dir}"

  local src_input="${vault_dir}/canonical_input.json"
  local src_report="${vault_dir}/final_report.md"
  local src_decision="${vault_dir}/decision_recommendation.json"
  local src_decision_sha="${vault_dir}/decision_recommendation.json.sha256"

  [[ -s "$src_input" ]] || fail "Missing required artifact: ${src_input}"
  [[ -s "$src_report" ]] || fail "Missing required artifact: ${src_report}"
  [[ -s "$src_decision" ]] || fail "Missing required artifact: ${src_decision}"
  [[ -s "$src_decision_sha" ]] || fail "Missing required artifact: ${src_decision_sha}"

  local stage_dir="${vault_dir}/package_staging"
  local package_root="${stage_dir}/package_v1"

  log "Preparing staging directory: ${stage_dir}"
  rm -rf "$stage_dir"
  mkdir -p "$package_root/input" "$package_root/report" "$package_root/decision"

  log "Copying required artifacts"
  cp "$src_input" "$package_root/input/canonical_input.json"
  cp "$src_report" "$package_root/report/final_report.md"
  cp "$src_decision" "$package_root/decision/decision_recommendation.json"
  cp "$src_decision_sha" "$package_root/decision/decision_recommendation.json.sha256"

  local report_hash
  report_hash="$(shasum -a 256 "$package_root/report/final_report.md" | awk '{print $1}')"
  printf '%s\n' "$report_hash" >"$package_root/report/final_report.md.sha256"

  if [[ -f "${vault_dir}/report.pdf" ]]; then
    log "Including optional report.pdf"
    cp "${vault_dir}/report.pdf" "$package_root/report/report.pdf"
  fi

  local agents_added=0
  for name in MASTER_REVIEW_AGENT SPEC_COMPLIANCE_AGENT FORMAL_MODEL_AGENT RISK_CLASSIFICATION_AGENT DEPLOYMENT_READINESS_AGENT; do
    if [[ -f "${vault_dir}/${name}.md" ]]; then
      if [[ $agents_added -eq 0 ]]; then
        mkdir -p "$package_root/agents"
      fi
      cp "${vault_dir}/${name}.md" "$package_root/agents/${name}.md"
      agents_added=1
    fi
  done

  local package_timestamp
  package_timestamp="$(read_timestamp_or_now "$package_root/input/canonical_input.json")"
  log "Using package timestamp: ${package_timestamp}"

  local report_sha256_canonical
  report_sha256_canonical="$(extract_report_hash "$package_root/report/final_report.md")"
  local decision_sha256
  decision_sha256="$(first_token "$package_root/decision/decision_recommendation.json.sha256")"

  log "Writing manifest.json"
  write_manifest "$package_root" "$input_sha256" "$package_timestamp" "$report_sha256_canonical" "$decision_sha256"

  log "Generating SHA256SUMS"
  build_sha256sums "$package_root"

  log "Normalizing file mtimes"
  normalize_mtimes "$package_root" "$package_timestamp"

  local zip_path
  zip_path="$(cd "$vault_dir" && pwd)/evidence_package_v1_${input_sha256}.zip"
  local zip_sha_path="${zip_path}.sha256"

  log "Creating ZIP package"
  rm -f "$zip_path" "$zip_sha_path"
  (cd "$stage_dir" && zip -X -r "$zip_path" package_v1 >/dev/null)

  local zip_hash
  zip_hash="$(shasum -a 256 "$zip_path" | awk '{print $1}')"
  printf '%s\n' "$zip_hash" >"$zip_sha_path"

  log "Package build complete"
  printf 'ZIP: %s\n' "$zip_path"
  printf 'ZIP SHA256: %s\n' "$zip_sha_path"
}

main "$@"