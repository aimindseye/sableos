#!/usr/bin/env python3
from __future__ import annotations

import json
import pathlib
import re
import subprocess
import tomllib
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
    ROOT / ".gitleaks.toml",
    ROOT / "build" / "trusted-runner-policy.json",
    ROOT / "build" / "check-runner-policy.py",
    ROOT / "build" / "audit-trusted-runner-host.py",
    ROOT / "build" / "host" / "verify-r8-host-tools.sh",
    ROOT / "build" / "host" / "bootstrap-r8-host-tools.sh",
    ROOT / "build" / "host" / "audit-r8-host-tools.sh",
    ROOT / "build" / "host" / "centralize-r8-security-tools.sh",
    ROOT / "build" / "host" / "cleanup-r8-host-tool-duplicates.sh",
    ROOT / ".githooks" / "pre-push",
    ROOT / "build" / "supply-chain-lock.json",
    ROOT / "build" / "generate-supply-chain-evidence.py",
    ROOT / "build" / "check-gradle-supply-chain.py",
    ROOT / "build" / "gates" / "r9-sms-mms-blocking-contract.py",
    ROOT / "build" / "gates" / "r9-first-party-app-icon-contract.py",
    ROOT / "apps" / "r8" / "rust" / "Cargo.lock",
    ROOT / "apps" / "r8" / "rust" / "rust-toolchain.toml",
    ROOT / "apps" / "r8" / "android" / "gradle" / "verification-metadata.xml",
)
for path in required:
    if not path.is_file():
        failures.append(f"required CI/supply-chain file missing: {path.relative_to(ROOT)}")

gitleaks_config = ROOT / ".gitleaks.toml"
if gitleaks_config.is_file():
    try:
        parsed_gitleaks = tomllib.loads(gitleaks_config.read_text(encoding="utf-8"))
    except Exception as exc:
        failures.append(f"invalid .gitleaks.toml: {exc}")
    else:
        allowlists = parsed_gitleaks.get("allowlists")
        if not isinstance(allowlists, list) or len(allowlists) != 4:
            failures.append(".gitleaks.toml must contain exactly four scoped allowlists")

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

layout_gate = ROOT / "build" / "check-repo-layout.sh"
if layout_gate.is_file():
    layout_text = layout_gate.read_text(encoding="utf-8")
    for token in (
        "build/panther/prepare-r8-final-ui.sh",
        "build/panther/build-r8-final-ui.sh",
        "build/panther/qualify-r9-physical-ux.sh",
        "patches/android-17-grapheneos-2026081300/apply_r9_launcher3_foundation.py",
        "patches/android-17-grapheneos-2026081300/r9_launcher3/SableQuickstepLauncher.kt",
        "R9_STANDALONE_SABLESTART_BUILD_ENTRYPOINT=PASS_ABSENT",
        "R9_STANDALONE_SABLESTART_MANIFEST=PASS_ABSENT",
        "R9_SABLESTART_PRESENTATION_FILEGROUP=PASS",
        "R9_LAUNCHER3_HOSTED_SABLESTART_LAYOUT=PASS",
    ):
        if token not in layout_text:
            failures.append(f"repo layout contract token missing: {token}")
    for obsolete_required in (
        "  build/panther/build-sablestart.sh\n",
        "  src/android/packages/apps/SableStart/AndroidManifest.xml\n",
    ):
        if obsolete_required in layout_text:
            failures.append(
                "obsolete standalone SableStart artifact remains in required layout: "
                + obsolete_required.strip()
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
        "SABLE_SECURITY_BIN",
        "SABLE_GITLEAKS",
        "SABLE_MOBSFSCAN",
        "r9-sms-mms-blocking-contract.py",
        "r9-first-party-app-icon-contract.py",
        ":weather:assembleDebug",
        ":weather:lintDebug",
        ":weather:detekt",
        ":weather:ktlintCheck",
        "weather-debug.apk",
        "r9-launcher-visual-acceptance.py",
        "SABLE_LOCAL_CI_STAGE_VISUAL_ACCEPTANCE=PASS",
        "run-r8-release-candidate.sh",
        "sable-local-ci",
        "SABLE_LOCAL_CI=PASS",
    ):
        if token not in text:
            failures.append(f"local CI contract token missing: {token}")

    forbidden_install_tokens = (
        "--dest \"$PINNED_TOOLS_DIR\"",
        "component add",
        "python3 -m venv",
        "pip install",
    )
    for token in forbidden_install_tokens:
        if token in text:
            failures.append(
                f"local CI must not install host tools; forbidden token present: {token}"
            )

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
