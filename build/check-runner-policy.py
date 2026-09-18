#!/usr/bin/env python3
from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"
POLICY = ROOT / "build" / "trusted-runner-policy.json"
failures: list[str] = []

if not POLICY.is_file():
    failures.append("trusted-runner-policy.json missing")
    policy = {}
else:
    try:
        policy = json.loads(POLICY.read_text(encoding="utf-8"))
    except Exception as exc:
        failures.append(f"invalid trusted-runner-policy.json: {exc}")
        policy = {}

expected = {
    "schema": "sableos-trusted-runner-policy-v1",
    "require_at_rest_encryption": True,
    "self_hosted_jobs_allowed": False,
    "ephemeral_required": True,
    "persistent_service_forbidden": True,
    "registration_secrets_must_not_be_persisted": True,
}
for key, value in expected.items():
    if policy.get(key) != value:
        failures.append(
            f"runner policy mismatch {key}: "
            f"actual={policy.get(key)!r} expected={value!r}"
        )

required_labels = [
    "self-hosted",
    "linux",
    "x64",
    "sable-trusted",
    "sable-ephemeral",
]
if policy.get("future_required_labels") != required_labels:
    failures.append("future_required_labels mismatch")

workflow_files = sorted(WORKFLOWS.glob("*.yml")) + sorted(WORKFLOWS.glob("*.yaml"))
if not workflow_files:
    failures.append("no workflow files found")

runs_on_count = 0
for path in workflow_files:
    text = path.read_text(encoding="utf-8")
    rel = path.relative_to(ROOT)
    low = text.lower()

    if "self-hosted" in low:
        failures.append(f"self-hosted runner use forbidden by INFRA4 policy: {rel}")
    if "sable-trusted" in low or "sable-ephemeral" in low:
        failures.append(f"trusted-runner labels present before activation: {rel}")
    if "pull_request_target:" in low:
        failures.append(
            f"pull_request_target forbidden while runner activation is disabled: {rel}"
        )

    for lineno, line in enumerate(text.splitlines(), 1):
        match = re.match(r"^\s*runs-on:\s*(.+?)\s*$", line)
        if not match:
            continue
        runs_on_count += 1
        value = match.group(1).strip().strip("'\"")
        if value != "ubuntu-22.04":
            failures.append(
                f"non-hosted-pinned runner at {rel}:{lineno}: {value}"
            )

tracked = subprocess.check_output(
    ["git", "-C", str(ROOT), "ls-files", "-z"]
).decode().split("\0")
for item in filter(None, tracked):
    p = pathlib.PurePosixPath(item)
    if p.name in {".runner", ".credentials", ".credentials_rsaparams"}:
        failures.append(f"GitHub runner credential/state file tracked: {item}")
    if "actions-runner" in {part.lower() for part in p.parts}:
        failures.append(f"GitHub Actions runner distribution tracked: {item}")

for path in (
    ROOT / "docs" / "INFRA4_TRUSTED_RUNNER_ENCRYPTION.md",
    ROOT / "build" / "audit-trusted-runner-host.py",
):
    if not path.is_file():
        failures.append(f"INFRA4 required file missing: {path.relative_to(ROOT)}")

if failures:
    for item in failures:
        print(f"FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print(f"INFRA4_WORKFLOW_FILE_COUNT={len(workflow_files)}")
print(f"INFRA4_RUNS_ON_COUNT={runs_on_count}")
print("INFRA4_SELF_HOSTED_WORKFLOW_COUNT=0")
print("INFRA4_RUNNER_POLICY=PASS")
