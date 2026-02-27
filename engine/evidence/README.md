# Deterministic Evidence Package v1.0

Deterministic Evidence Package (DEP) v1.0 is a portable, bank-grade packaging format for audit evidence produced by this repository.

It is designed for:
- Reproducible evidence exchange between institutions
- Independent verification by risk, audit, and compliance teams
- Content-level determinism (same canonical content produces the same manifest and checksums)
- Tamper-evident transfer through explicit SHA-256 inventories

The package is built from an existing evidence vault entry:
- `vault/<input_sha256>/`

## Why Banks Use This

Banks need verifiable controls around:
- Data lineage
- Integrity of decision artifacts
- Reproducibility of compliance evidence
- Independent validation by second and third lines of defense

DEP v1.0 provides a standard structure, a machine-readable manifest, and deterministic checksum inventory (`SHA256SUMS`) to support those controls.

## Build a Package

```bash
./engine/evidence/tools/build_package.sh <input_sha256>
```

Example:

```bash
./engine/evidence/tools/build_package.sh 8b5f1c...ab12
```

Output:
- `vault/<input_sha256>/evidence_package_v1_<input_sha256>.zip`
- `vault/<input_sha256>/evidence_package_v1_<input_sha256>.zip.sha256`

## Verify a Package

```bash
./engine/evidence/tools/verify_package.sh vault/<input_sha256>/evidence_package_v1_<input_sha256>.zip
```

On success, verifier prints:
- `input_sha256` from manifest
- `VERIFY PACKAGE: PASS`

## Specification

Full standard:
- `engine/evidence/specs/deterministic_evidence_package_v1.md`
