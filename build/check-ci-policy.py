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
