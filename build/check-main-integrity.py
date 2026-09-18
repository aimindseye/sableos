#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FULL_SHA = re.compile(r"^[0-9a-f]{40}$")
ZERO_SHA = "0" * 40

def fail(reason: str) -> None:
    print(f"SABLE_MAIN_INTEGRITY_FAIL={reason}", file=sys.stderr)
    raise SystemExit(1)

def git(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

parser = argparse.ArgumentParser()
parser.add_argument("--before", required=True)
parser.add_argument("--after", required=True)
args = parser.parse_args()

before = args.before.lower()
after = args.after.lower()

if not FULL_SHA.fullmatch(before):
    fail("BEFORE_SHA_INVALID")
if not FULL_SHA.fullmatch(after):
    fail("AFTER_SHA_INVALID")
if before == ZERO_SHA:
    fail("MAIN_CREATION_EVENT_NOT_ACCEPTED")
if after == ZERO_SHA:
    fail("MAIN_DELETION_EVENT_NOT_ACCEPTED")
if before == after:
    fail("MAIN_UPDATE_HAS_IDENTICAL_BEFORE_AFTER")

for label, sha in (("before", before), ("after", after)):
    result = git("cat-file", "-e", f"{sha}^{{commit}}", check=False)
    if result.returncode != 0:
        fail(f"{label.upper()}_COMMIT_NOT_PRESENT")

ancestry = git("merge-base", "--is-ancestor", before, after, check=False)
if ancestry.returncode != 0:
    fail("MAIN_UPDATE_NOT_FAST_FORWARD")

required = (
    ROOT / ".githooks" / "pre-push",
    ROOT / ".github" / "workflows" / "main-integrity.yml",
    ROOT / "build" / "check-ci-policy.py",
    ROOT / "build" / "check-main-integrity.py",
    ROOT / "docs" / "INFRA2C_FREE_GOVERNANCE.md",
)
for path in required:
    if not path.is_file():
        fail(f"REQUIRED_GOVERNANCE_FILE_MISSING:{path.relative_to(ROOT)}")

stage = git("ls-files", "--stage", ".githooks/pre-push").stdout.strip()
if not stage.startswith("100755 "):
    fail("PRE_PUSH_HOOK_NOT_TRACKED_EXECUTABLE")

print(f"SABLE_MAIN_INTEGRITY_BEFORE={before}")
print(f"SABLE_MAIN_INTEGRITY_AFTER={after}")
print("SABLE_MAIN_INTEGRITY_FAST_FORWARD=PASS")
print("SABLE_MAIN_GOVERNANCE_FILES=PASS")
print("SABLE_MAIN_INTEGRITY=PASS")
