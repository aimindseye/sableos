#!/usr/bin/env python3
from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"
failures: list[str] = []

workflow_files: list[pathlib.Path] = []
if WORKFLOWS.exists():
    workflow_files = sorted(WORKFLOWS.glob("*.yml")) + sorted(WORKFLOWS.glob("*.yaml"))
if workflow_files:
    failures.append(
        "hosted GitHub CI remains executable: "
        + ", ".join(str(p.relative_to(ROOT)) for p in workflow_files)
    )

required = (
    ROOT / "build" / "local-ci" / "run.sh",
    ROOT / "build" / "local-ci" / "README.md",
    ROOT / "build" / "trusted-runner-policy.json",
    ROOT / "build" / "check-runner-policy.py",
    ROOT / "build" / "audit-trusted-runner-host.py",
    ROOT / "build" / "host" / "verify-r8-host-tools.sh",
    ROOT / ".githooks" / "pre-push",
    ROOT / "build" / "supply-chain-lock.json",
    ROOT / "build" / "generate-supply-chain-evidence.py",
    ROOT / "build" / "check-gradle-supply-chain.py",
    ROOT / "apps" / "r8" / "rust" / "Cargo.lock",
    ROOT / "apps" / "r8" / "rust" / "rust-toolchain.toml",
    ROOT / "apps" / "r8" / "android" / "gradle" / "verification-metadata.xml",
)
for path in required:
    if not path.is_file():
        failures.append(f"required CI/supply-chain file missing: {path.relative_to(ROOT)}")

policy_path = ROOT / "build" / "trusted-runner-policy.json"
if policy_path.is_file():
    try:
        policy = json.loads(policy_path.read_text(encoding="utf-8"))
    except Exception as exc:
        failures.append(f"invalid trusted-runner-policy.json: {exc}")
        policy = {}
    for key, expected in (
        ("ci_execution_mode", "LOCAL_DIRECT"),
        ("github_actions_execution_allowed", False),
        ("local_ci_remote_trigger_allowed", False),
        ("self_hosted_actions_jobs_allowed", False),
    ):
        if policy.get(key) != expected:
            failures.append(
                f"CI execution policy mismatch {key}: "
                f"actual={policy.get(key)!r} expected={expected!r}"
            )

local_ci = ROOT / "build" / "local-ci" / "run.sh"
if local_ci.is_file():
    text = local_ci.read_text(encoding="utf-8")
    for token in (
        "GITHUB_ACTIONS_EXECUTION=DISABLED",
        "SELF_HOSTED_ACTIONS_RUNNER=DISABLED",
        "build/check-ci-policy.py",
        "build/check-runner-policy.py",
        "build/check-repo-layout.sh",
        "build/host/verify-r8-host-tools.sh",
        "cargo-audit",
        "cargo-deny",
        "gitleaks",
        "mobsfscan",
        "run-r8-release-candidate.sh",
        "sable-local-ci",
        "SABLE_LOCAL_CI=PASS",
    ):
        if token not in text:
            failures.append(f"local CI contract token missing: {token}")

stage = subprocess.check_output(
    ["git", "-C", str(ROOT), "ls-files", "--stage", ".githooks/pre-push"],
    text=True,
).strip()
if not stage.startswith("100755 "):
    failures.append(".githooks/pre-push must remain tracked executable mode 100755")

toolchain = ROOT / "apps" / "r8" / "rust" / "rust-toolchain.toml"
if toolchain.is_file():
    t = toolchain.read_text(encoding="utf-8")
    if not re.search(r'^channel\s*=\s*"1\.\d+\.\d+"\s*$', t, re.MULTILINE):
        failures.append("Rust toolchain channel is not an exact x.y.z release")
    if 'targets = ["aarch64-linux-android"]' not in t:
        failures.append("Rust Android target missing from rust-toolchain.toml")

runner = ROOT / "build" / "check-runner-policy.py"
if runner.is_file():
    proc = subprocess.run(
        [sys.executable, str(runner)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.stdout:
        print(proc.stdout, end="")
    if proc.returncode != 0:
        if proc.stderr:
            print(proc.stderr, file=sys.stderr, end="")
        failures.append("local CI runner policy failed")

if failures:
    for item in failures:
        print(f"FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("GITHUB_ACTIONS_EXECUTION=DISABLED")
print("SABLE_LOCAL_CI_POLICY=PASS")
