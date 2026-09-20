#!/usr/bin/env python3
from __future__ import annotations

import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"
POLICY = ROOT / "build" / "trusted-runner-policy.json"
failures: list[str] = []

try:
    policy = json.loads(POLICY.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"FAIL: invalid trusted-runner-policy.json: {exc}", file=sys.stderr)
    raise SystemExit(1)

expected = {
    "schema": "sableos-ci-execution-policy-v2",
    "ci_execution_mode": "LOCAL_DIRECT",
    "github_actions_execution_allowed": False,
    "local_ci_execution_allowed": True,
    "local_ci_remote_trigger_allowed": False,
    "self_hosted_actions_jobs_allowed": False,
    "persistent_actions_service_forbidden": True,
    "registration_secrets_must_not_be_persisted": True,
    "require_at_rest_encryption_for_future_actions_runner": True,
    "untrusted_pull_request_remote_execution_allowed": False,
}
for key, value in expected.items():
    if policy.get(key) != value:
        failures.append(
            f"runner policy mismatch {key}: "
            f"actual={policy.get(key)!r} expected={value!r}"
        )

workflow_files = []
if WORKFLOWS.exists():
    workflow_files = sorted(WORKFLOWS.glob("*.yml")) + sorted(WORKFLOWS.glob("*.yaml"))
if workflow_files:
    failures.append(
        "GitHub Actions workflows must be absent in LOCAL_DIRECT mode: "
        + ", ".join(str(p.relative_to(ROOT)) for p in workflow_files)
    )

tracked = subprocess.check_output(
    ["git", "-C", str(ROOT), "ls-files", "-z"]
).decode().split("\0")
for item in filter(None, tracked):
    p = pathlib.PurePosixPath(item)
    if p.name in {".runner", ".credentials", ".credentials_rsaparams"}:
        failures.append(f"GitHub Actions runner credential/state file tracked: {item}")
    if "actions-runner" in {part.lower() for part in p.parts}:
        failures.append(f"GitHub Actions runner distribution tracked: {item}")

for path in (
    ROOT / "build" / "local-ci" / "run.sh",
    ROOT / "build" / "local-ci" / "README.md",
    ROOT / "docs" / "INFRA4_TRUSTED_RUNNER_ENCRYPTION.md",
    ROOT / "build" / "audit-trusted-runner-host.py",
):
    if not path.is_file():
        failures.append(f"required local-CI file missing: {path.relative_to(ROOT)}")

if failures:
    for item in failures:
        print(f"FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("SABLE_CI_EXECUTION_MODE=LOCAL_DIRECT")
print("GITHUB_ACTIONS_WORKFLOW_COUNT=0")
print("GITHUB_SELF_HOSTED_RUNNER=DISABLED")
print("LOCAL_DIRECT_CI=ENABLED")
print("SABLE_RUNNER_POLICY=PASS")
