#!/usr/bin/env python3
"""Validate SableOS KF1 device-profile JSON using only the Python stdlib.

This intentionally checks the invariants Sable depends on at design/build time
without requiring a third-party JSON Schema package. The JSON Schema file
remains the normative structural contract.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]+$")
CAP_RE = re.compile(r"^[A-Z0-9_]+$")
POLICY_RE = re.compile(r"^[A-Z0-9_]+$")

VALID_INTERACTION = {"TOUCH_FIRST", "KEYBOARD_FIRST", "HYBRID"}
VALID_SUPPORT = {
    "REFERENCE_FROZEN",
    "N0_GSI_USERSPACE_LAB",
    "N1_INTEGRATED_VENDOR_BSP_PORT",
    "N2_PRODUCTION_QUALIFIED",
    "RESEARCH",
}
VALID_EVIDENCE = {"PHYSICALLY_VERIFIED", "PARTIAL", "RESEARCH_ONLY"}
VALID_DISPLAY_ID_POLICY = {"DISCOVER", "FIXED"}


def require(condition: bool, errors: list[str], message: str) -> None:
    if not condition:
        errors.append(message)


def unique_ids(items: list[dict[str, Any]], field: str, errors: list[str]) -> None:
    seen: set[str] = set()
    for idx, item in enumerate(items):
        value = item.get("id")
        require(isinstance(value, str) and bool(ID_RE.fullmatch(value)), errors,
                f"{field}[{idx}].id invalid: {value!r}")
        if isinstance(value, str):
            require(value not in seen, errors, f"{field} duplicate id: {value}")
            seen.add(value)


def validate(profile: dict[str, Any]) -> list[str]:
    errors: list[str] = []

    require(profile.get("schema_version") == 1, errors, "schema_version must be 1")

    profile_id = profile.get("profile_id")
    require(isinstance(profile_id, str) and bool(ID_RE.fullmatch(profile_id)), errors,
            "profile_id must use lowercase id syntax")

    device_class = profile.get("device_class")
    require(isinstance(device_class, str) and bool(re.fullmatch(r"[a-z0-9][a-z0-9-]+", device_class or "")),
            errors, "device_class must use canonical lowercase device syntax")

    require(profile.get("interaction_profile") in VALID_INTERACTION, errors,
            "interaction_profile is invalid")
    require(profile.get("support_level") in VALID_SUPPORT, errors,
            "support_level is invalid")

    evidence = profile.get("evidence")
    require(isinstance(evidence, dict), errors, "evidence must be an object")
    if isinstance(evidence, dict):
        require(evidence.get("state") in VALID_EVIDENCE, errors, "evidence.state is invalid")
        require(bool(evidence.get("source_repository")), errors,
                "evidence.source_repository is required")
        docs = evidence.get("source_documents")
        require(isinstance(docs, list) and bool(docs), errors,
                "evidence.source_documents must be a non-empty list")
        if isinstance(docs, list):
            require(len(docs) == len(set(docs)), errors,
                    "evidence.source_documents contains duplicates")
        baseline = evidence.get("baseline")
        require(isinstance(baseline, dict), errors, "evidence.baseline must be an object")
        if isinstance(baseline, dict):
            require(bool(baseline.get("stock_build")), errors,
                    "evidence.baseline.stock_build is required")
            require(isinstance(baseline.get("android_release"), int), errors,
                    "evidence.baseline.android_release must be an integer")

    displays = profile.get("displays")
    require(isinstance(displays, list) and bool(displays), errors,
            "displays must be a non-empty list")
    if isinstance(displays, list):
        unique_ids(displays, "displays", errors)
        primary_count = 0
        for idx, display in enumerate(displays):
            if not isinstance(display, dict):
                errors.append(f"displays[{idx}] must be an object")
                continue
            if display.get("role") == "PRIMARY":
                primary_count += 1
            policy = display.get("android_display_id_policy")
            require(policy in VALID_DISPLAY_ID_POLICY, errors,
                    f"displays[{idx}].android_display_id_policy invalid")
            if policy == "DISCOVER":
                require("android_display_id" not in display, errors,
                        f"displays[{idx}] must not hard-code android_display_id when policy=DISCOVER")
            if policy == "FIXED":
                require(isinstance(display.get("android_display_id"), int), errors,
                        f"displays[{idx}] FIXED policy requires integer android_display_id")
            for key in ("native_width_px", "native_height_px", "base_density_dpi"):
                require(isinstance(display.get(key), int) and display[key] > 0, errors,
                        f"displays[{idx}].{key} must be positive integer")
            require(isinstance(display.get("refresh_hz"), (int, float)) and display["refresh_hz"] > 0,
                    errors, f"displays[{idx}].refresh_hz must be positive")
        require(primary_count == 1, errors,
                f"exactly one PRIMARY display is required, found {primary_count}")

    surfaces = profile.get("input_surfaces")
    require(isinstance(surfaces, list) and bool(surfaces), errors,
            "input_surfaces must be a non-empty list")
    if isinstance(surfaces, list):
        unique_ids(surfaces, "input_surfaces", errors)
        for idx, surface in enumerate(surfaces):
            if not isinstance(surface, dict):
                errors.append(f"input_surfaces[{idx}] must be an object")
                continue
            require(bool(surface.get("linux_name")), errors,
                    f"input_surfaces[{idx}].linux_name is required")
            caps = surface.get("capabilities")
            require(isinstance(caps, list) and bool(caps), errors,
                    f"input_surfaces[{idx}].capabilities must be non-empty")
            if isinstance(caps, list):
                require(len(caps) == len(set(caps)), errors,
                        f"input_surfaces[{idx}].capabilities contains duplicates")
                for cap in caps:
                    require(isinstance(cap, str) and bool(CAP_RE.fullmatch(cap)), errors,
                            f"input_surfaces[{idx}] invalid capability: {cap!r}")
            semantic = surface.get("semantic_default")
            if isinstance(semantic, str):
                require(not semantic.startswith("KEYCODE_"), errors,
                        f"input_surfaces[{idx}] semantic_default must be a Sable semantic, not raw keycode")
                require(semantic != "404", errors,
                        f"input_surfaces[{idx}] must not expose vendor key 404 as a common semantic")

    indicators = profile.get("indicators")
    require(isinstance(indicators, list), errors, "indicators must be a list")
    if isinstance(indicators, list):
        unique_ids(indicators, "indicators", errors)
        for idx, indicator in enumerate(indicators):
            if not isinstance(indicator, dict):
                errors.append(f"indicators[{idx}] must be an object")
                continue
            lo = indicator.get("api_min")
            hi = indicator.get("api_max")
            if lo is not None or hi is not None:
                require(isinstance(lo, int) and isinstance(hi, int) and lo <= hi, errors,
                        f"indicators[{idx}] api_min/api_max invalid")
            eff_lo = indicator.get("effective_min_nonzero")
            eff_hi = indicator.get("effective_max")
            if eff_lo is not None and eff_hi is not None:
                require(isinstance(eff_lo, int) and isinstance(eff_hi, int) and eff_lo <= eff_hi,
                        errors, f"indicators[{idx}] effective range invalid")

    compat = profile.get("vendor_compatibility")
    require(isinstance(compat, list), errors, "vendor_compatibility must be a list")
    if isinstance(compat, list):
        unique_ids(compat, "vendor_compatibility", errors)
        for idx, item in enumerate(compat):
            if not isinstance(item, dict):
                errors.append(f"vendor_compatibility[{idx}] must be an object")
                continue
            if item.get("kind") == "SYNTHETIC_ANDROID_KEY" and item.get("stock_value") == 404:
                require(item.get("sable_exposure") != "NORMALIZE_TO_COMMON_SEMANTIC", errors,
                        "vendor Android key 404 must not become a common Sable semantic")

    decisions = profile.get("policy_decisions")
    require(isinstance(decisions, list), errors, "policy_decisions must be a list")
    if isinstance(decisions, list):
        seen: set[str] = set()
        for idx, decision in enumerate(decisions):
            if not isinstance(decision, dict):
                errors.append(f"policy_decisions[{idx}] must be an object")
                continue
            did = decision.get("id")
            require(isinstance(did, str) and bool(POLICY_RE.fullmatch(did)), errors,
                    f"policy_decisions[{idx}].id invalid")
            if isinstance(did, str):
                require(did not in seen, errors, f"policy_decisions duplicate id: {did}")
                seen.add(did)
            state = decision.get("state")
            require(state in {"UNDECIDED", "DECIDED", "DEFERRED"}, errors,
                    f"policy_decisions[{idx}].state invalid")
            if state == "DECIDED":
                require(bool(decision.get("decision")), errors,
                        f"policy_decisions[{idx}] DECIDED requires decision text")
            if state == "UNDECIDED":
                require(decision.get("decision") in (None, ""), errors,
                        f"policy_decisions[{idx}] UNDECIDED must not contain a decision")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("profiles", nargs="+", type=Path)
    args = parser.parse_args()

    failed = False
    for path in args.profiles:
        try:
            profile = json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            print(f"KF1_DEVICE_PROFILE=FAIL path={path} error={exc}")
            failed = True
            continue

        if not isinstance(profile, dict):
            print(f"KF1_DEVICE_PROFILE=FAIL path={path} error=root_not_object")
            failed = True
            continue

        errors = validate(profile)
        if errors:
            failed = True
            print(f"KF1_DEVICE_PROFILE=FAIL path={path} errors={len(errors)}")
            for error in errors:
                print(f"  - {error}")
        else:
            print(
                "KF1_DEVICE_PROFILE=PASS "
                f"path={path} "
                f"profile_id={profile['profile_id']} "
                f"device={profile['device_class']} "
                f"interaction={profile['interaction_profile']}"
            )

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
