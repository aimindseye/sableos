#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"
FULL_SHA = re.compile(r"^[0-9a-fA-F]{40}$")
USES = re.compile(r"^\s*-?\s*uses:\s*([^\s#]+)")
SEMVER = re.compile(r'^channel\s*=\s*"(1\.\d+\.\d+)"\s*$', re.MULTILINE)
failures: list[str] = []

workflow_files = sorted(WORKFLOWS.glob("*.yml")) + sorted(WORKFLOWS.glob("*.yaml"))
if not workflow_files:
    failures.append("no workflow files found")

for path in workflow_files:
    text = path.read_text(encoding="utf-8")
    rel = path.relative_to(ROOT)
    before_jobs = text.split("\njobs:", 1)[0]
    if "\npermissions:" not in before_jobs:
        failures.append(f"missing explicit top-level permissions: {rel}")
    if "runs-on: ubuntu-latest" in text:
        failures.append(f"mutable major runner alias ubuntu-latest: {rel}")
    for lineno, line in enumerate(text.splitlines(), 1):
        m = USES.match(line)
        if not m:
            continue
        ref = m.group(1)
        if ref.startswith("./"):
            continue
        if "@" not in ref:
            failures.append(f"unversioned Action {rel}:{lineno}: {ref}")
            continue
        revision = ref.rsplit("@", 1)[1]
        if not FULL_SHA.fullmatch(revision):
            failures.append(f"Action not pinned to full SHA {rel}:{lineno}: {ref}")

all_workflow_text = "\n".join(p.read_text(encoding="utf-8") for p in workflow_files)
if "cargo generate-lockfile" in all_workflow_text:
    failures.append("CI must consume committed Cargo.lock; cargo generate-lockfile found")
if "cargo install cargo-audit --version 0.22.2 --locked" not in all_workflow_text:
    failures.append("cargo-audit exact version pin missing")

for required in ("r8-android.yml", "r8-apk-seal.yml"):
    text = (WORKFLOWS / required).read_text(encoding="utf-8")
    if "'ndk;30.0.16248370'" not in text:
        failures.append(f"pinned NDK install missing: {required}")
    if "targets: aarch64-linux-android" not in text:
        failures.append(f"Rust Android target install missing: {required}")

quality_workflow = WORKFLOWS / "quality-coverage.yml"
if not quality_workflow.is_file():
    failures.append("quality-coverage workflow missing")
else:
    qtext = quality_workflow.read_text(encoding="utf-8")
    required_quality_tokens = (
        "cargo install cargo-llvm-cov --version 0.9.1 --locked",
        "components: llvm-tools-preview",
        "toolchain: '1.98.1'",
        "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a",
        ":design:koverXmlReportDebug",
        ":design:detekt",
        ":design:ktlintCheck",
    )
    for token in required_quality_tokens:
        if token not in qtext:
            failures.append(f"quality/coverage pin or task missing: {token}")

android_root_gradle = ROOT / "apps" / "r8" / "android" / "build.gradle.kts"
if not android_root_gradle.is_file():
    failures.append("apps/r8/android/build.gradle.kts missing")
else:
    gtext = android_root_gradle.read_text(encoding="utf-8")
    required_gradle_plugins = (
        'id("io.gitlab.arturbosch.detekt") version "1.23.8" apply false',
        'id("org.jlleitschuh.gradle.ktlint") version "14.2.0" apply false',
        'id("org.jetbrains.kotlinx.kover") version "0.9.9" apply false',
        'version.set("1.8.0")',
    )
    for token in required_gradle_plugins:
        if token not in gtext:
            failures.append(f"quality Gradle pin missing: {token}")

governance_hook = ROOT / ".githooks" / "pre-push"
if not governance_hook.is_file():
    failures.append("committed .githooks/pre-push missing")
else:
    stage = subprocess.check_output(
        ["git", "-C", str(ROOT), "ls-files", "--stage", ".githooks/pre-push"],
        text=True,
    ).strip()
    if not stage.startswith("100755 "):
        failures.append(".githooks/pre-push must be tracked executable mode 100755")

main_integrity = WORKFLOWS / "main-integrity.yml"
if not main_integrity.is_file():
    failures.append("main-integrity workflow missing")
else:
    mitext = main_integrity.read_text(encoding="utf-8")
    required_main_integrity_tokens = (
        "branches: [main]",
        "fetch-depth: 0",
        "python3 build/check-ci-policy.py",
        "python3 build/check-main-integrity.py",
        "actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803",
    )
    for token in required_main_integrity_tokens:
        if token not in mitext:
            failures.append(f"main-integrity policy token missing: {token}")

main_integrity_checker = ROOT / "build" / "check-main-integrity.py"
if not main_integrity_checker.is_file():
    failures.append("build/check-main-integrity.py missing")

free_governance_doc = ROOT / "docs" / "INFRA2C_FREE_GOVERNANCE.md"
if not free_governance_doc.is_file():
    failures.append("docs/INFRA2C_FREE_GOVERNANCE.md missing")

lock = ROOT / "apps" / "r8" / "rust" / "Cargo.lock"
if not lock.is_file():
    failures.append("committed apps/r8/rust/Cargo.lock missing")

toolchain = ROOT / "apps" / "r8" / "rust" / "rust-toolchain.toml"
if not toolchain.is_file():
    failures.append("apps/r8/rust/rust-toolchain.toml missing")
else:
    text = toolchain.read_text(encoding="utf-8")
    if not SEMVER.search(text):
        failures.append("Rust toolchain channel is not an exact x.y.z release")
    if 'targets = ["aarch64-linux-android"]' not in text:
        failures.append("Rust Android target missing from rust-toolchain.toml")

tracked = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "-z"]).decode().split("\0")
for item in filter(None, tracked):
    p = pathlib.Path(item)
    if p.name in {"id_rsa", "id_ed25519"} or p.suffix.lower() in {".jks", ".keystore", ".p12", ".pfx"}:
        failures.append(f"high-risk credential container tracked: {item}")

if failures:
    for item in failures:
        print(f"FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("SABLE_CI_POLICY=PASS")
