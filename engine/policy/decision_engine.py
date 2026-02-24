#!/usr/bin/env python3
import json
import sys
from pathlib import Path

ENGINE_VERSION = "1.1.0-policy"

def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)

def apply_policy_rules(canonical_input: dict) -> list[str]:
    flags: list[str] = []

    risk_acceptance_signed = bool(canonical_input.get("risk_acceptance_signed", False))

    econ = canonical_input.get("economic_assumptions", {}) or {}
    governance_latency_hours = float(econ.get("governance_latency_hours", 0))
    liquidity_24h_pct = float(econ.get("liquidity_24h_pct", 100))

    formal_model_present = bool(canonical_input.get("formal_model_present", False))
    spec_present = bool(canonical_input.get("spec_present", False))
    monitoring_defined = bool(canonical_input.get("monitoring_defined", False))
    emergency_mechanism_defined = bool(canonical_input.get("emergency_mechanism_defined", False))

    if not risk_acceptance_signed:
        flags.append("risk_acceptance_not_signed")

    if governance_latency_hours > 48:
        flags.append("governance_latency_exceeded")

    if liquidity_24h_pct < 15:
        flags.append("low_liquidity")

    if not formal_model_present:
        flags.append("formal_model_missing")

    if not spec_present:
        flags.append("spec_missing")

    if not monitoring_defined:
        flags.append("monitoring_not_defined")

    if not emergency_mechanism_defined:
        flags.append("emergency_mechanism_missing")

    return flags

def determine_recommendation(policy_flags: list[str]) -> tuple[str, str]:
    if any(f in policy_flags for f in [
        "risk_acceptance_not_signed",
        "formal_model_missing",
        "spec_missing",
        "emergency_mechanism_missing",
    ]):
        return "REJECT", "CRITICAL"

    if "governance_latency_exceeded" in policy_flags:
        return "ESCALATE", "HIGH"

    if any(f in policy_flags for f in ["low_liquidity", "monitoring_not_defined"]):
        return "CONDITIONAL", "MEDIUM"

    return "APPROVE", "LOW"

def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python3 engine/policy/decision_engine.py engine/output/canonical_input.json", file=sys.stderr)
        return 2

    input_path = Path(sys.argv[1])
    if not input_path.is_file():
        print(f"ERROR: input not found: {input_path}", file=sys.stderr)
        return 1

    canonical_input = load_json(input_path)

    flags = apply_policy_rules(canonical_input)
    decision, risk_class = determine_recommendation(flags)

    out = {
        "deterministic": True,
        "engine_version": ENGINE_VERSION,
        "recommended_decision": decision,
        "risk_class": risk_class,
        "policy_flags": flags,
        "escalation_required": decision in ["ESCALATE", "CONDITIONAL"],
    }

    output_path = input_path.parent / "decision_recommendation.json"
    # Deterministic JSON: sort_keys + compact separators
    with output_path.open("w", encoding="utf-8") as f:
        json.dump(out, f, sort_keys=True, separators=(",", ":"))
        f.write("\n")

    print(f"Decision written to {output_path}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())