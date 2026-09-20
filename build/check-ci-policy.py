#!/usr/bin/env python3
from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys
import urllib.parse

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
if "cargo install " in all_workflow_text:
    failures.append("runtime cargo install is forbidden in CI")
for token in ("curl ", "wget "):
    if token in all_workflow_text:
        failures.append(f"direct unverified network download token found in CI: {token.strip()}")

for token in ("--write-locks", "--write-verification-metadata"):
    if token in all_workflow_text:
        failures.append(f"Gradle bootstrap write flag forbidden after INFRA3 baseline: {token}")

for required in ("r8-android.yml", "r8-apk-seal.yml"):
    text = (WORKFLOWS / required).read_text(encoding="utf-8")
    if "'ndk;30.0.16248370'" not in text:
        failures.append(f"pinned NDK install missing: {required}")
    if "targets: aarch64-linux-android" not in text:
        failures.append(f"Rust Android target install missing: {required}")

tool_lock = ROOT / "build" / "supply-chain-lock.json"
installer = ROOT / "build" / "install-pinned-tool.py"
generator = ROOT / "build" / "generate-supply-chain-evidence.py"
supply_workflow = WORKFLOWS / "supply-chain.yml"

gradle_checker = ROOT / "build" / "check-gradle-supply-chain.py"
sablestart_signing_gate = ROOT / "build" / "gates" / "r8-sablestart-signing-policy.py"
r8_final_build = ROOT / "build" / "panther" / "build-r8-final-ui.sh"
r8_target_files_gate = ROOT / "build" / "gates" / "r8-final-target-files.sh"
r8_closure_workflow = WORKFLOWS / "r8-final-ui-closure.yml"
r8_mail_workflow = WORKFLOWS / "r8-mail.yml"
r8_product_composition_gate = ROOT / "build" / "gates" / "r8-final-product-composition.sh"
sablestart_bp = ROOT / "src" / "android" / "packages" / "apps" / "SableStart" / "Android.bp"
sablestart_manifest = ROOT / "src" / "android" / "packages" / "apps" / "SableStart" / "AndroidManifest.xml"
sable_system_bars = ROOT / "src" / "android" / "shared" / "sabledesign" / "src" / "main" / "java" / "org" / "sableos" / "design" / "SableSystemBars.kt"
runner_checker = ROOT / "build" / "check-runner-policy.py"
runner_policy = ROOT / "build" / "trusted-runner-policy.json"
runner_host_audit = ROOT / "build" / "audit-trusted-runner-host.py"

for path in (
    tool_lock,
    installer,
    generator,
    gradle_checker,
    sablestart_signing_gate,
    r8_final_build,
    r8_target_files_gate,
    r8_closure_workflow,
    r8_mail_workflow,
    r8_product_composition_gate,
    sablestart_bp,
    sablestart_manifest,
    sable_system_bars,
    runner_checker,
    runner_policy,
    runner_host_audit,
    supply_workflow,
):
    if not path.is_file():
        failures.append(f"INFRA3 supply-chain file missing: {path.relative_to(ROOT)}")

if sablestart_signing_gate.is_file():
    signing_proc = subprocess.run(
        [sys.executable, str(sablestart_signing_gate), "--self-test"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if signing_proc.stdout:
        print(signing_proc.stdout, end="")
    if signing_proc.returncode != 0:
        if signing_proc.stderr:
            print(signing_proc.stderr, file=sys.stderr, end="")
        failures.append("R8 SableStart signing-policy self-test failed")

if sablestart_bp.is_file():
    bp_text = sablestart_bp.read_text(encoding="utf-8")
    if "v4_signature: false," not in bp_text:
        failures.append("SableStart must explicitly disable v4_signature")
    if "v4_signature: true," in bp_text:
        failures.append("SableStart v4_signature true is forbidden")

for path, tokens in (
    (
        r8_final_build,
        (
            "r8-sablestart-signing-policy.py",
            "R8_SABLESTART_SIGNING_SOURCE_POLICY=PASS",
            "R8_SABLESTART_SIGNING_TARGET_FILES_POLICY=PASS",
        ),
    ),
    (
        r8_target_files_gate,
        (
            "r8-sablestart-signing-policy.py",
            "R8_SABLESTART_SIGNING_POLICY_TARGET_FILES=PASS",
        ),
    ),
    (
        r8_closure_workflow,
        (
            "SableStart signing policy contract",
            "R8_SABLESTART_SIGNING_POLICY_CI=PASS",
            "build/gates/r8-sablestart-signing-policy.py --self-test",
        ),
    ),
):
    if path.is_file():
        text = path.read_text(encoding="utf-8")
        for token in tokens:
            if token not in text:
                failures.append(
                    f"R8 SableStart signing-policy token missing: "
                    f"{path.relative_to(ROOT)}: {token}"
                )

if sable_system_bars.is_file():
    system_bars_text = sable_system_bars.read_text(encoding="utf-8")
    for required in (
        "val decorView = window.decorView",
        "decorView.windowInsetsController?.setSystemBarsAppearance(",
        "if (decorView.isAttachedToWindow)",
        "decorView.post { applyAppearance() }",
    ):
        if required not in system_bars_text:
            failures.append(f"Sable system-bar lifecycle guard missing: {required}")
    if "window.insetsController" in system_bars_text:
        failures.append(
            "direct Window.insetsController access is forbidden in SableSystemBars"
        )

if sablestart_manifest.is_file():
    manifest_text = sablestart_manifest.read_text(encoding="utf-8")
    if '<intent-filter android:priority="1">' not in manifest_text:
        failures.append("SableStart HOME intent must retain priority=1")
    if 'android.intent.category.HOME' not in manifest_text:
        failures.append("SableStart HOME category missing")

for path, tokens in (
    (
        r8_product_composition_gate,
        (
            "R8_SABLESTART_SYSTEM_BARS_LIFECYCLE=PASS",
            "R8_SABLESTART_HOME_PRIORITY=PASS",
        ),
    ),
    (
        r8_closure_workflow,
        (
            "R8_SABLESTART_SYSTEM_BARS_LIFECYCLE=PASS",
            "R8_SABLESTART_HOME_PRIORITY=PASS",
        ),
    ),
):
    if path.is_file():
        policy_text = path.read_text(encoding="utf-8")
        for token in tokens:
            if token not in policy_text:
                failures.append(
                    f"SableStart runtime policy token missing: "
                    f"{path.relative_to(ROOT)}: {token}"
                )

if r8_mail_workflow.is_file():
    mail_text = r8_mail_workflow.read_text(encoding="utf-8")
    for forbidden in (
        "'src/android/shared/sabledesign/**'",
        "'src/android/packages/apps/SableStart/**'",
        "'.github/workflows/r8-mail.yml'",
    ):
        if forbidden in mail_text:
            failures.append(
                f"Sable Mail heavy CI trigger must stay narrow; forbidden path: {forbidden}"
            )
    for required in (
        "'apps/r8/mail/apply_sable_flavor.py'",
        "'apps/r8/mail/verify_sable_mail.py'",
        "'apps/r8/mail/upstream.env'",
    ):
        if required not in mail_text:
            failures.append(f"Sable Mail heavy CI trigger missing: {required}")

if tool_lock.is_file():
    try:
        lock_doc = json.loads(tool_lock.read_text(encoding="utf-8"))
    except Exception as exc:
        failures.append(f"invalid supply-chain-lock.json: {exc}")
        lock_doc = {}

    expected_tools = {
        "cargo-audit": (
            "0.22.2",
            "7fb9497f8594b389e5fce5ef9b92db08432996895b2e0c5a0167a69ed445c428",
        ),
        "cargo-deny": (
            "0.20.2",
            "9f12ed4c49936e09b48bf862b595cde2fe64fcbd9d74dfacac6131ca824c8d5f",
        ),
        "cargo-llvm-cov": (
            "0.9.1",
            "3fca950394a3c49457657c158b1619cec8dfd2647ae5b48746734c0ab969a522",
        ),
    }
    tools = lock_doc.get("tools", {})
    expected_version_args = {
        "cargo-audit": ["--version"],
        "cargo-deny": ["--version"],
        "cargo-llvm-cov": ["llvm-cov", "--version"],
    }
    for name, (version, digest) in expected_tools.items():
        item = tools.get(name)
        if not isinstance(item, dict):
            failures.append(f"pinned tool missing: {name}")
            continue
        if item.get("version") != version:
            failures.append(f"pinned tool version mismatch: {name}")
        if item.get("sha256") != digest:
            failures.append(f"pinned tool SHA-256 mismatch: {name}")
        if item.get("version_args") != expected_version_args[name]:
            failures.append(f"pinned tool version probe mismatch: {name}")
        url = item.get("url", "")
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "https" or parsed.netloc.lower() != "github.com":
            failures.append(f"pinned tool URL is not GitHub HTTPS: {name}")

required_installer_uses = {
    "r8-rust-security.yml": "--tool cargo-audit",
    "security-baseline.yml": "--tool cargo-deny",
    "quality-coverage.yml": "--tool cargo-llvm-cov",
}
for workflow, token in required_installer_uses.items():
    text = (WORKFLOWS / workflow).read_text(encoding="utf-8")
    if "build/install-pinned-tool.py" not in text or token not in text:
        failures.append(f"checksum-verified pinned tool install missing: {workflow}")

quality_workflow = WORKFLOWS / "quality-coverage.yml"
if quality_workflow.is_file():
    qtext = quality_workflow.read_text(encoding="utf-8")
    required_quality_tokens = (
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

if supply_workflow.is_file():
    stext = supply_workflow.read_text(encoding="utf-8")
    required_supply_tokens = (
        "python3 build/install-pinned-tool.py --all",
        "cargo-llvm-cov llvm-cov --version",
        "build/check-gradle-supply-chain.py",
        ":calculator:compileDebugNavigationResources",
        "INFRA3_AAPT2_DETACHED_VERIFICATION_PATH=PASS",
        ":design:lintDebug",
        "INFRA3_LINT_DETACHED_VERIFICATION_PATH=PASS",
        "INFRA3_GRADLE_STATE_BEFORE.json",
        "INFRA3_GRADLE_STATE_AFTER.json",
        "r8-android-gradle-supply-chain-evidence-${{ github.sha }}",
        "SABLE_R8_RUST_SBOM.cdx.json",
        "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a",
    )
    for token in required_supply_tokens:
        if token not in stext:
            failures.append(f"supply-chain workflow token missing: {token}")

apk_seal = WORKFLOWS / "r8-apk-seal.yml"
if apk_seal.is_file():
    atext = apk_seal.read_text(encoding="utf-8")
    for token in (
        "build/generate-supply-chain-evidence.py",
        "R8_SUPPLY_CHAIN_PROVENANCE.json",
        "R8_RUST_SBOM.cdx.json",
        "R8_SUPPLY_CHAIN_PROVENANCE.sha256",
    ):
        if token not in atext:
            failures.append(f"APK provenance token missing: {token}")

expected_gradle_lockfiles = {
    "apps/r8/android/calculator/gradle.lockfile",
    "apps/r8/android/convert/gradle.lockfile",
    "apps/r8/android/design/gradle.lockfile",
    "apps/r8/android/games/gradle.lockfile",
    "apps/r8/android/media/gradle.lockfile",
}
actual_gradle_lockfiles = {
    str(path.relative_to(ROOT))
    for path in (ROOT / "apps" / "r8" / "android").rglob("gradle.lockfile")
    if path.is_file()
}
if actual_gradle_lockfiles != expected_gradle_lockfiles:
    failures.append(
        "Gradle lockfile set mismatch: "
        f"actual={sorted(actual_gradle_lockfiles)} "
        f"expected={sorted(expected_gradle_lockfiles)}"
    )

gradle_verification = ROOT / "apps" / "r8" / "android" / "gradle" / "verification-metadata.xml"
if not gradle_verification.is_file():
    failures.append("Gradle verification-metadata.xml missing")

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
        "lockAllConfigurations()",
    )
    for token in required_gradle_plugins:
        if token not in gtext:
            failures.append(f"quality/reproducibility Gradle token missing: {token}")

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

tracked = subprocess.check_output(
    ["git", "-C", str(ROOT), "ls-files", "-z"]
).decode().split("\0")
for item in filter(None, tracked):
    p = pathlib.Path(item)
    if p.name in {"id_rsa", "id_ed25519"} or p.suffix.lower() in {
        ".jks",
        ".keystore",
        ".p12",
        ".pfx",
    }:
        failures.append(f"high-risk credential container tracked: {item}")

if runner_checker.is_file():
    runner_proc = subprocess.run(
        [sys.executable, str(runner_checker)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if runner_proc.stdout:
        print(runner_proc.stdout, end="")
    if runner_proc.returncode != 0:
        if runner_proc.stderr:
            print(runner_proc.stderr, file=sys.stderr, end="")
        failures.append("INFRA4 trusted-runner policy check failed")

if failures:
    for item in failures:
        print(f"FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("SABLE_CI_POLICY=PASS")
