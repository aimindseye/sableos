#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re
import sys

ANSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
MARKER_RE = re.compile(r"^([A-Z][A-Z0-9_-]*)=(.*)$")

STAGE_ORDER = [
    "POLICY",
    "STATIC",
    "TITAN2_N1B2_EVIDENCE",
    "RUST",
    "ANDROID",
    "APK_SEAL",
    "QUALITY",
    "SUPPLY_CHAIN",
    "SECURITY",
    "TEXTREADER",
    "READER",
    "MAIL",
    "VISUAL_ACCEPTANCE",
    "RELEASE",
]

CORE_KEYS = [
    "SABLE_LOCAL_CI_STATIC_CONTRACTS",
    "SABLE_LOCAL_CI_APPLICATOR_SELF_TESTS",
    "SABLE_LOCAL_CI_PYTHON_SYNTAX",
    "SABLE_LOCAL_CI_QUALITY_ANDROID",
    "SABLE_LOCAL_CI_SHARED_SECURITY_TOOLS",
]

REGRESSION_KEYS = [
    "SABLE_BUILD_REGRESSION_COUNT",
    "SABLE_BUILD_REGRESSION_CONTRACT",
    "SABLE_BUILD_REGRESSION_T2-001",
    "SABLE_BUILD_REGRESSION_T2-008",
    "SABLE_BUILD_REGRESSION_T2-013",
    "SABLE_BUILD_REGRESSION_T2-014",
    "SABLE_BUILD_REGRESSION_T2-015",
    "SABLE_BUILD_REGRESSION_T2-016",
    "SABLE_BUILD_REGRESSION_T2-017",
]

TITAN_N1I_KEYS = [
    "N1I_C1_ANDROID_PLATFORM",
    "N1I_C1_ANDROID_17_ALLOWED",
    "N1I_C1_A4_NATIVE_SUPERSET_COUNT",
    "N1I_C1_STOCK_NATIVE_PREBUILT_COUNT",
    "N1I_C1_CONFIG_PREBUILT_COUNT",
    "N1I_C1_REGISTRATION_DATA_DELTA",
    "N1I_C1_NEW_FUNCTIONAL_DELTA",
    "N1I_C1_ANDROID16_CONTRACT",
    "SABLE_LOCAL_CI_TITAN2_N1I_STATIC_CONTRACTS",
]

SECURITY_KEYS = [
    "SABLE_GITLEAKS_HISTORY_SCOPE",
    "GITLEAKS_FINDING_COUNT",
    "SABLE_GITLEAKS",
]

FAILURE_PREFIXES = (
    "SABLE_",
    "N1I_",
    "TITAN2_",
    "GITLEAKS_",
)


def parse_markers(log_text: str) -> dict[str, str]:
    markers: dict[str, str] = {}
    for raw in log_text.splitlines():
        line = ANSI_RE.sub("", raw).strip()
        match = MARKER_RE.match(line)
        if match is None:
            continue
        markers[match.group(1)] = match.group(2).strip()
    return markers


def append_present(lines: list[str], markers: dict[str, str], keys: list[str]) -> None:
    for key in keys:
        if key in markers:
            lines.append(f"{key}={markers[key]}")


def render_summary(
    *,
    markers: dict[str, str],
    profile: str,
    device: str,
    release: str,
    source_commit: str,
    evidence_dir: str,
    summary_file: str,
    exit_code: int,
) -> str:
    lines = [
        "===== SABLE LOCAL CI FINAL SUMMARY =====",
        f"SABLE_LOCAL_CI_SUMMARY_STATUS={'PASS' if exit_code == 0 else 'FAIL'}",
        f"SABLE_LOCAL_CI={'PASS' if exit_code == 0 else 'FAIL'}",
        f"PROFILE={profile}",
        f"SABLEOS_DEVICE={device}",
        f"SABLEOS_RELEASE_VERSION={release}",
        f"SOURCE_COMMIT={source_commit}",
        f"CI_EXIT_CODE={exit_code}",
    ]

    if "NETWORK_FETCH_AUTHORIZED" in markers:
        lines.append(f"NETWORK_FETCH_AUTHORIZED={markers['NETWORK_FETCH_AUTHORIZED']}")

    lines.append("--- STAGES ---")
    emitted_stages = set()
    for stage in STAGE_ORDER:
        key = f"SABLE_LOCAL_CI_STAGE_{stage}"
        if key in markers:
            lines.append(f"{key}={markers[key]}")
            emitted_stages.add(key)

    extra_stage_keys = sorted(
        key
        for key in markers
        if key.startswith("SABLE_LOCAL_CI_STAGE_")
        and not key.endswith("_LOG_SCAN")
        and key not in emitted_stages
    )
    for key in extra_stage_keys:
        lines.append(f"{key}={markers[key]}")

    lines.append("--- CONTRACTS / REGRESSIONS ---")
    append_present(lines, markers, CORE_KEYS)
    append_present(lines, markers, REGRESSION_KEYS)

    if device.lower() == "titan2" and release.upper() == "N1I":
        lines.append("--- TITAN2 N1I ---")
        append_present(lines, markers, TITAN_N1I_KEYS)

    if profile in {"full", "release"}:
        lines.append("--- SECURITY ---")
        append_present(lines, markers, SECURITY_KEYS)

    failures = []
    for key, value in markers.items():
        if not key.startswith(FAILURE_PREFIXES):
            continue
        if value.startswith("FAIL"):
            failures.append((key, value))
    if failures:
        lines.append("--- FAILURE MARKERS ---")
        for key, value in sorted(failures)[:24]:
            lines.append(f"{key}={value}")

    lines.extend([
        f"EVIDENCE_DIR={evidence_dir}",
        f"SUMMARY_FILE={summary_file}",
        "===== END SABLE LOCAL CI FINAL SUMMARY =====",
    ])
    return "\n".join(lines) + "\n"


def self_test() -> int:
    sample = """
PROFILE=full
NETWORK_FETCH_AUTHORIZED=NO
SABLE_LOCAL_CI_STAGE_POLICY=PASS
SABLE_BUILD_REGRESSION_T2-017=PASS configured_jar_locations_match_installed_stems
SABLE_BUILD_REGRESSION_COUNT=19
SABLE_BUILD_REGRESSION_CONTRACT=PASS
N1I_C1_ANDROID_PLATFORM=16
N1I_C1_ANDROID16_CONTRACT=PASS
SABLE_GITLEAKS_HISTORY_SCOPE=SOURCE_COMMIT commit=abc
GITLEAKS_FINDING_COUNT=0
SABLE_GITLEAKS=PASS report=/tmp/report.json
SABLE_LOCAL_CI_STAGE_MAIL=PASS
"""
    markers = parse_markers(sample)
    rendered = render_summary(
        markers=markers,
        profile="full",
        device="titan2",
        release="N1I",
        source_commit="a" * 40,
        evidence_dir="/tmp/evidence",
        summary_file="/tmp/evidence/LOCAL_CI_SUMMARY.txt",
        exit_code=0,
    )
    required = (
        "SABLE_LOCAL_CI_SUMMARY_STATUS=PASS",
        "SABLE_LOCAL_CI_STAGE_POLICY=PASS",
        "SABLE_LOCAL_CI_STAGE_MAIL=PASS",
        "SABLE_BUILD_REGRESSION_T2-017=PASS configured_jar_locations_match_installed_stems",
        "N1I_C1_ANDROID16_CONTRACT=PASS",
        "GITLEAKS_FINDING_COUNT=0",
        "SUMMARY_FILE=/tmp/evidence/LOCAL_CI_SUMMARY.txt",
    )
    missing = [token for token in required if token not in rendered]
    if missing:
        print("SABLE_LOCAL_CI_SUMMARY_SELFTEST=FAIL")
        for token in missing:
            print(f"MISSING={token}")
        return 1
    failed_markers = parse_markers(
        sample
        + """
SABLE_LOCAL_CI_STAGE_ANDROID=FAIL compile
N1I_C1_ANDROID16_CONTRACT=FAIL fixture
"""
    )
    failed = render_summary(
        markers=failed_markers,
        profile="full",
        device="titan2",
        release="N1I",
        source_commit="b" * 40,
        evidence_dir="/tmp/evidence-fail",
        summary_file="/tmp/evidence-fail/LOCAL_CI_SUMMARY.txt",
        exit_code=7,
    )
    required_failure = (
        "SABLE_LOCAL_CI_SUMMARY_STATUS=FAIL",
        "SABLE_LOCAL_CI=FAIL",
        "CI_EXIT_CODE=7",
        "SABLE_LOCAL_CI_STAGE_ANDROID=FAIL compile",
        "N1I_C1_ANDROID16_CONTRACT=FAIL fixture",
        "--- FAILURE MARKERS ---",
    )
    missing_failure = [token for token in required_failure if token not in failed]
    if missing_failure:
        print("SABLE_LOCAL_CI_SUMMARY_SELFTEST=FAIL")
        for token in missing_failure:
            print(f"MISSING_FAILURE={token}")
        return 1

    print("SABLE_LOCAL_CI_SUMMARY_SELFTEST=PASS")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--log")
    parser.add_argument("--out")
    parser.add_argument("--profile")
    parser.add_argument("--device")
    parser.add_argument("--release")
    parser.add_argument("--source-commit")
    parser.add_argument("--evidence-dir")
    parser.add_argument("--exit-code", type=int)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        return self_test()

    required = (
        "log",
        "out",
        "profile",
        "device",
        "release",
        "source_commit",
        "evidence_dir",
        "exit_code",
    )
    missing = [name for name in required if getattr(args, name) is None]
    if missing:
        parser.error("missing required arguments: " + ", ".join(missing))

    log_path = pathlib.Path(args.log)
    out_path = pathlib.Path(args.out)
    log_text = log_path.read_text(encoding="utf-8", errors="replace") if log_path.is_file() else ""
    markers = parse_markers(log_text)
    rendered = render_summary(
        markers=markers,
        profile=args.profile,
        device=args.device,
        release=args.release,
        source_commit=args.source_commit,
        evidence_dir=args.evidence_dir,
        summary_file=str(out_path),
        exit_code=args.exit_code,
    )
    out_path.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
