#!/usr/bin/env python3
"""Fail-closed, read-only source-completion prerequisite for the *next* TB2 build.

Does not claim IMS registration, physical Q25 UX parity, AVB or flash readiness.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
MANIFEST = ROOT / "build/titan2/nextbuild/Q25_SOURCE_READINESS.json"
EXPECTED_BASE = "7ead6fcf37ffc231ea168b18641bcc7b1c7ae8ab"
IDS = (
    "start-titan2-3page", "all-apps-titan2", "command-titan2", "hub-titan2",
    "messages-conversation-titan2", "phone-dialer-titan2",
    "contacts-people-titan2", "lockscreen-titan2", "quick-settings-titan2",
    "settings-titan2-approved", "setup-wizard-titan2", "battery-health-usage-titan2",
    "mobile-manager-app-controls-titan2", "private-space-dual-work-titan2",
    "connectivity-otg-nfc-cast-titan2", "camera-capture-titan2",
    "browser-webview-titan2", "files-documents-titan2",
    "mail-calendar-titan2", "media-gallery-titan2",
    "utilities-notes-recorder-titan2", "toolbox-hardware-titan2",
    "subscreen-shortcut-keyboard-titan2",
)
REQUIREMENTS = (
    "effective-single-provider", "installed-package-and-privapp-identity",
    "G1-framework-classes-and-bindings", "G2-native-linker-and-abi",
    "G3-vendor-ims-transport", "hard-restricted-sms-role",
    "fresh-selected-apk-provenance",
    "SableLauncher-home-and-quickstep-recents",
)
HEX64 = re.compile(r"^[a-f0-9]{64}$")


def hold(reason: str) -> int:
    print(f"TB2_NEXTBUILD_READINESS=HOLD_{reason}")
    return 78


def verify_receipt(row: dict) -> bool:
    if row["status"] != "complete":
        return True
    rel = row.get("evidence_file")
    wanted = row.get("evidence_sha256")
    if not isinstance(rel, str) or not isinstance(wanted, str) or not HEX64.fullmatch(wanted):
        return False
    path = pathlib.PurePosixPath(rel)
    if path.is_absolute() or not path.parts or any(part in (".", "..") for part in path.parts):
        return False
    candidate = ROOT
    for part in path.parts:
        candidate = candidate / part
        if candidate.is_symlink():
            return False
    if not candidate.is_file() or candidate.stat().st_size > 1_048_576:
        return False
    return hashlib.sha256(candidate.read_bytes()).hexdigest() == wanted


def check(mode: str) -> int:
    try:
        if MANIFEST.is_symlink() or not MANIFEST.is_file():
            return hold("MANIFEST_MISSING_OR_SYMLINK")
        doc = json.loads(MANIFEST.read_text(encoding="utf-8"))
        if doc.get("schema") != "TB2_NEXTBUILD_SOURCE_READINESS_V1":
            return hold("SCHEMA_DRIFT")
        if doc.get("base_commit") != EXPECTED_BASE:
            return hold("BASE_DRIFT")
        items = doc["items"]
        requirements = doc["requirements"]
        if not isinstance(items, list) or not isinstance(requirements, list):
            return hold("INVALID_ROW_TYPES")
        if tuple(row["id"] for row in items) != IDS:
            return hold("EXACT_Q25_ROWS_DRIFT")
        if tuple(row["id"] for row in requirements) != REQUIREMENTS:
            return hold("SOURCE_REQUIREMENTS_DRIFT")
        valid = {"open", "complete", "not_applicable"}
        if any(row["status"] not in valid for row in items):
            return hold("INVALID_Q25_STATUS")
        if any(row["status"] not in {"open", "complete"} for row in requirements):
            return hold("INVALID_SOURCE_STATUS")
        if items[-1]["status"] != "not_applicable" or any(
            row["status"] == "not_applicable" for row in items[:-1]
        ):
            return hold("INAPPLICABLE_ROW_DRIFT")
        if not all(verify_receipt(row) for row in items + requirements):
            return hold("RECEIPT_MISSING_OR_MISMATCH")
        pending = [row["id"] for row in items + requirements if row["status"] == "open"]
        print(f"TB2_NEXTBUILD_Q25_ROWS=23 ACTIVE=22 OPEN={sum(row['status'] == 'open' for row in items)}")
        print(f"TB2_NEXTBUILD_IMS_AND_ROLES_OPEN={sum(row['status'] == 'open' for row in requirements)}")
        if pending:
            for name in pending:
                print(f"TB2_NEXTBUILD_SOURCE_OPEN={name}")
            if mode == "require-ready":
                return hold("Q25_AND_IMS_SCOPE_OPEN")
            print("TB2_NEXTBUILD_READINESS=REPORT_OPEN_NO_MUTATION")
            return 0
        print("TB2_NEXTBUILD_READINESS=SOURCE_RECEIPTS_PRESENT_REVIEW_REQUIRED")
        return 0
    except (OSError, ValueError, TypeError, KeyError, AttributeError, json.JSONDecodeError) as exc:
        return hold(f"INVALID_MANIFEST_{type(exc).__name__.upper()}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", action="store_true")
    parser.add_argument("--require-ready", action="store_true")
    args = parser.parse_args()
    if args.report == args.require_ready:
        parser.error("select exactly one of --report or --require-ready")
    return check("require-ready" if args.require_ready else "report")


if __name__ == "__main__":
    sys.exit(main())
