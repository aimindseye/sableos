#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

failures: list[str] = []


def require(rel: str, *needles: str) -> None:
    path = ROOT / rel
    if not path.is_file():
        failures.append(f"missing_file={rel}")
        return
    text = path.read_text(encoding="utf-8")
    for needle in needles:
        if needle not in text:
            failures.append(f"missing_token={rel}:{needle}")


require(
    "docs/R9_SYSTEM_COHESION_CLOSURE.md",
    "physical R9 candidate rejected",
    "WS0 — Baseline and acceptance contract",
    "WS1 — System-owned appearance authority",
    "WS2 — Launcher and Quickstep ownership",
    "WS3 — Sable Settings control center",
    "WS4 — SystemUI and key system surfaces",
    "WS5 — Core apps and Reader",
    "WS6 — Residual platform and branding audit",
    "WS7 — Integrated pre-image qualification",
    "WS8 — Fresh Panther candidate and physical acceptance",
    "R9_SABLE_NATIVE_LAUNCHER_ESCAPE=PASS_ABSENT",
    "R9_SABLE_APPEARANCE_BOOT_RESTORE=PASS",
    "R9_PHYSICAL_DAILY_DRIVER_ACCEPTANCE=PASS",
)

require(
    "docs/R9_FINAL_UI_RUNTIME_ACCEPTANCE.md",
    "R9_PHYSICAL_PANTHER_VISUAL_ACCEPTANCE=REQUIRED",
    "R9_FINAL_VISUAL_AUTHORITY=PHYSICAL_PANTHER",
)

if failures:
    print("R9_SYSTEM_COHESION_BASELINE=FAIL")
    for failure in failures:
        print(f"FAILURE={failure}")
    raise SystemExit(1)

print("R9_REJECTED_PHYSICAL_CANDIDATE_BOUND=PASS")
print("R9_SYSTEM_COHESION_WORKSTREAM_ORDER=PASS")
print("R9_NO_NATIVE_LAUNCHER_ESCAPE_FINAL_GATE=REQUIRED")
print("R9_SYSTEM_APPEARANCE_BOOT_RESTORE_FINAL_GATE=REQUIRED")
print("R9_PHYSICAL_DAILY_DRIVER_FINAL_GATE=REQUIRED")
print("R9_SYSTEM_COHESION_BASELINE=PASS")
