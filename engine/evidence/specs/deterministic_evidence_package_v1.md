# Deterministic Evidence Package v1.0 Specification

## 1. Scope

This specification defines the **Deterministic Evidence Package v1.0** format for packaging evidence artifacts from a deterministic analysis run into a portable, auditable archive.

The package is intended for financial institutions, risk committees, internal audit, regulators, and independent validation teams.

## 2. Conformance Language

The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** in this document are to be interpreted as normative requirements.

## 3. Package Model

### 3.1 Package Root

A conforming ZIP archive MUST contain a top-level directory named:

- `package_v1/`

### 3.2 Required Files

The following files MUST exist under `package_v1/`:

- `manifest.json`
- `SHA256SUMS`
- `input/canonical_input.json`
- `report/final_report.md`
- `report/final_report.md.sha256`
- `decision/decision_recommendation.json`
- `decision/decision_recommendation.json.sha256`

### 3.3 Optional Files

The following files MAY be included when available:

- `report/report.pdf`
- `agents/*.md` (for example `agents/MASTER_REVIEW_AGENT.md`)

## 4. Manifest (manifest.json)

`manifest.json` MUST be valid JSON and include at least:

- `package_version` (string): MUST be `"1.0"`
- `input_sha256` (string): vault input hash identifier
- `report_sha256_canonical` (string): extracted from `final_report.md` line `Report Hash (SHA-256): \`...\``; empty string if absent
- `decision_sha256` (string): first token from `decision/decision_recommendation.json.sha256`
- `included_files` (array of strings): sorted relative file paths under `package_v1/`, excluding `manifest.json` and `SHA256SUMS`
- `package_build_timestamp_utc` (string): UTC timestamp used for deterministic file mtime normalization
- `tool_versions` (object) with keys:
  - `python3`
  - `zip`
  - `shasum`

`manifest.json` SHOULD be pretty-printed and MUST use stable key ordering.

## 5. SHA256SUMS

`SHA256SUMS` MUST contain one line per file under `package_v1/` except `SHA256SUMS` itself.

Line format MUST be:

`<sha256_hex>  <relative_path>`

Where:
- hash uses SHA-256
- relative path is relative to `package_v1/`
- paths MUST NOT be absolute
- entries MUST be sorted by path using `LC_ALL=C` lexical ordering

## 6. Determinism Model

DEP v1.0 guarantees **content determinism** at the package-content layer:

- Canonical artifacts (`canonical_input.json`, final report, decision artifacts)
- Deterministic manifest field ordering and included file ordering
- Deterministic checksum inventory (`SHA256SUMS`)

ZIP archives include filesystem metadata that can vary across environments. DEP v1.0 minimizes ZIP metadata variability by:

- Using `zip -X` (exclude extra file attributes)
- Normalizing staged file mtimes to a single deterministic timestamp before zipping

Even if ZIP bytes differ across environments, verifiers MUST trust the package integrity based on:
- `SHA256SUMS` verification
- Manifest consistency checks

## 7. Build Requirements

A conforming builder:
- MUST fail if required vault artifacts are missing
- MUST stage files under a deterministic package structure
- MUST normalize staged mtimes to the selected UTC timestamp
- MUST generate `manifest.json` and `SHA256SUMS` per this spec
- MUST produce ZIP and ZIP SHA256 sidecar

## 8. Verification Requirements

A conforming verifier:
- MUST extract archive in isolation
- MUST ensure `package_v1/manifest.json` and `package_v1/SHA256SUMS` exist
- MUST verify every listed file hash in `SHA256SUMS`
- MUST fail on missing files, malformed checksum lines, or hash mismatch
- SHOULD print `input_sha256` from `manifest.json`
- MUST print `VERIFY PACKAGE: PASS` only on complete success
