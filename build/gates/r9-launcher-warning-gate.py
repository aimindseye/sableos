#!/usr/bin/env python3
from __future__ import annotations

import argparse
import collections
import pathlib
import re
import sys

WARNING_RE = re.compile(r"^(?P<prefix>.*?)(?P<message>warning: .+)$")

SABLE_PATH_MARKERS = (
    "packages/apps/SableDesign/",
    "packages/apps/Launcher3/quickstep/src/com/android/launcher3/sable/",
)

MIGRATED_WARNING_MARKERS = (
    "this annotation is currently applied to the value parameter only",
    "getParcelableExtra(p0: String",
    "'constructor(): Handler' is deprecated",
    "getParcelableArrayList(p0: String?)",
    "PreviewContext.kt:",
    "corresponding parameter in the supertype",
    "overrides a deprecated member but is not marked as deprecated itself",
    "statusBarColor: Int' is deprecated",
    "navigationBarColor: Int' is deprecated",
    "MESSAGE_ID_UPDATE_SHAPE: Int' is deprecated",
    "MESSAGE_ID_UPDATE_GRID: Int' is deprecated",
    "MESSAGE_ID_UPDATE_ICON_THEMED: Int' is deprecated",
)


def classify(line: str) -> str:
    if "[removal]" in line:
        return "removal"
    if "deprecated" in line.lower():
        return "deprecation"
    if "unchecked cast" in line:
        return "unchecked_cast"
    if "type mismatch" in line:
        return "type_mismatch"
    return "other"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=pathlib.Path)
    args = parser.parse_args()

    if not args.log.is_file():
        print(f"R9_LAUNCHER3_WARNING_GATE=FAIL missing_log={args.log}", file=sys.stderr)
        return 2

    lines = args.log.read_text(encoding="utf-8", errors="replace").splitlines()
    warnings = [line for line in lines if "warning:" in line.lower() or "Warning:" in line]

    categories = collections.Counter(classify(line) for line in warnings)
    fatal: list[str] = []

    for line in warnings:
        if any(marker in line for marker in SABLE_PATH_MARKERS):
            fatal.append(f"SABLE_WARNING {line}")
            continue
        if any(marker in line for marker in MIGRATED_WARNING_MARKERS):
            fatal.append(f"MIGRATED_WARNING_REGRESSION {line}")

    print(f"R9_LAUNCHER3_WARNING_COUNT={len(warnings)}")
    print(f"R9_LAUNCHER3_DEPRECATION_COUNT={categories['deprecation']}")
    print(f"R9_LAUNCHER3_REMOVAL_COUNT={categories['removal']}")
    print(f"R9_LAUNCHER3_UNCHECKED_CAST_COUNT={categories['unchecked_cast']}")
    print(f"R9_LAUNCHER3_TYPE_MISMATCH_COUNT={categories['type_mismatch']}")

    if categories["deprecation"] or categories["removal"]:
        print(
            "R9_LAUNCHER3_UPSTREAM_DEPRECATION_DEBT=REMAINS "
            f"count={categories['deprecation'] + categories['removal']}"
        )
    else:
        print("R9_LAUNCHER3_UPSTREAM_DEPRECATION_DEBT=ZERO")

    if fatal:
        for item in fatal:
            print(f"FAIL: {item}", file=sys.stderr)
        print("R9_LAUNCHER3_WARNING_GATE=FAIL", file=sys.stderr)
        return 1

    print("R9_LAUNCHER3_SABLE_WARNING_COUNT=0")
    print("R9_LAUNCHER3_MIGRATED_WARNING_REGRESSIONS=0")
    print("R9_LAUNCHER3_WARNING_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
