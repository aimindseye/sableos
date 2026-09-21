#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

POLICY_MARKERS = (
    "R9_MAC_VISUAL_ACCEPTANCE=WAIVED_BY_USER_FOR_R9",
    "R9_PHYSICAL_PANTHER_VISUAL_ACCEPTANCE=REQUIRED",
    "R9_FINAL_VISUAL_AUTHORITY=PHYSICAL_PANTHER",
)


def fail(label: str, detail: str = "") -> None:
    suffix = f" {detail}" if detail else ""
    print(f"{label}=FAIL{suffix}", file=sys.stderr)
    print("NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO", file=sys.stderr)
    raise SystemExit(1)


def main() -> int:
    runtime = ROOT / "docs/R9_FINAL_UI_RUNTIME_ACCEPTANCE.md"
    design = ROOT / "docs/R9_SABLESTART_LAUNCHER_DESIGN.md"
    start = (
        ROOT
        / "src/android/packages/apps/SableStart/src/com/sable/start/ui"
        / "SableStartScreen.kt"
    )

    for path in (runtime, design, start):
        if not path.is_file():
            fail("R9_VISUAL_ACCEPTANCE_POLICY", f"missing={path.relative_to(ROOT)}")

    policy_text = runtime.read_text(encoding="utf-8") + "\n" + design.read_text(encoding="utf-8")
    for marker in POLICY_MARKERS:
        if marker not in policy_text:
            fail("R9_VISUAL_ACCEPTANCE_POLICY", f"missing_marker={marker}")

    start_text = start.read_text(encoding="utf-8")
    for token in (
        "SettingsShortcut(",
        "ApprovedStartNavigationRow(",
        "ApprovedLiveRow(",
        "private fun AppsScreen(",
        "private fun SearchScreen(",
    ):
        if token not in start_text:
            fail("R9_VISUAL_ACCEPTANCE_PRODUCTION_SOURCE", f"missing_token={token}")

    print("R9_MAC_VISUAL_ACCEPTANCE=WAIVED_BY_USER_FOR_R9")
    print("R9_SABLESTART_VISUAL_REVIEW_SET=WAIVED_MAC")
    print("R9_L6_VISUAL_REVIEW_STATUS=WAIVED_MAC_DEFERRED_PHYSICAL_PANTHER")
    print("R9_L6_VISUAL_REVIEW_SCOPE=PHYSICAL_PANTHER_REQUIRED")
    print("R9_PHYSICAL_PANTHER_VISUAL_ACCEPTANCE=REQUIRED")
    print("R9_FINAL_VISUAL_AUTHORITY=PHYSICAL_PANTHER")
    print("NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
