#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
LAUNCHER3_HEAD = "e5fde8f4368539554b07ee136abd27bc7b4284c1"


def require(text: str, token: str, label: str, failures: list[str]) -> None:
    if token not in text:
        failures.append(f"{label}: missing {token!r}")


def forbid(text: str, token: str, label: str, failures: list[str]) -> None:
    if token in text:
        failures.append(f"{label}: forbidden {token!r}")


def check() -> list[str]:
    failures: list[str] = []

    baseline = (
        ROOT / "patches/android-17-grapheneos-2026081300/BASELINE.lock"
    ).read_text(encoding="utf-8")
    require(
        baseline,
        f"LAUNCHER3_HEAD={LAUNCHER3_HEAD}",
        "Launcher3 baseline",
        failures,
    )

    start_root = ROOT / "src/android/packages/apps/SableStart"
    start_bp = (start_root / "Android.bp").read_text(encoding="utf-8")
    require(
        start_bp,
        'name: "sable_start_presentation_srcs"',
        "Sable presentation filegroup",
        failures,
    )
    forbid(start_bp, "android_app {", "standalone SableStart app", failures)
    forbid(start_bp, "rust_ffi_shared {", "standalone SableStart JNI", failures)

    retired = (
        "AndroidManifest.xml",
        "rust/src/lib.rs",
        "src/com/sable/start/SableStartActivity.kt",
        "src/com/sable/start/bridge/SableStartNative.kt",
        "src/com/sable/start/platform/LauncherAppsRepository.kt",
    )
    for rel in retired:
        if (start_root / rel).exists():
            failures.append(f"retired SableStart path still exists: {rel}")

    screen = (
        start_root / "src/com/sable/start/ui/SableStartScreen.kt"
    ).read_text(encoding="utf-8")
    for token in (
        "homeGeneration: Int = 0",
        "backGeneration: Int = 0",
        "onCanNavigateBackChanged: (Boolean) -> Unit = {}",
        "LaunchedEffect(homeGeneration)",
        "LaunchedEffect(backGeneration)",
        "LaunchedEffect(destination)",
    ):
        require(screen, token, "host-driven Sable navigation", failures)
    forbid(screen, "BackHandler(", "Quickstep-owned Back dispatch", failures)
    forbid(
        screen,
        "androidx.activity.compose.BackHandler",
        "Quickstep-owned Back import",
        failures,
    )

    host_path = (
        ROOT
        / "patches/android-17-grapheneos-2026081300"
        / "r9_launcher3"
        / "SableQuickstepLauncher.kt"
    )
    if not host_path.is_file():
        failures.append("SableQuickstepLauncher canonical host missing")
        host = ""
    else:
        host = host_path.read_text(encoding="utf-8")
    for token in (
        "class SableQuickstepLauncher : QuickstepLauncher()",
        "activityComponent.appsStore",
        "store.addUpdateListener(appsUpdateListener)",
        "startActivitySafely(",
        "PackageManagerHelper.startDetailsActivityForInfo(",
        "override fun onStateSetStart(state: LauncherState)",
        "override fun onStateSetEnd(state: LauncherState)",
        "protected override fun getOnBackAnimationCallback()",
        "SableStartScreen(",
        "updateSableVisibility(isInState(LauncherState.NORMAL))",
    ):
        require(host, token, "Sable Quickstep host", failures)

    applicator = (
        ROOT
        / "patches/android-17-grapheneos-2026081300"
        / "apply_r9_launcher3_foundation.py"
    )
    if not applicator.is_file():
        failures.append("Launcher3 foundation applicator missing")
    else:
        text = applicator.read_text(encoding="utf-8")
        for token in (
            f'LAUNCHER3_HEAD = "{LAUNCHER3_HEAD}"',
            '":sable_start_presentation_srcs",',
            '":sable_design_shared_srcs",',
            "com.android.launcher3.sable.SableQuickstepLauncher",
            'android:authorities="org.sableos.start.appearance"',
            "R9_LAUNCHER3_FOUNDATION_VERIFY=PASS",
        ):
            require(text, token, "Launcher3 foundation applicator", failures)

        proc = subprocess.run(
            [sys.executable, str(applicator), "--self-test"],
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
            failures.append("Launcher3 foundation applicator self-test failed")

    product = (ROOT / "product/r8/panther/r8-product.mk").read_text(
        encoding="utf-8"
    )
    forbid(product, "    SableStart", "Panther standalone HOME product", failures)
    require(
        product,
        "Launcher3QuickStep remains the platform launcher package",
        "Panther Launcher3 product contract",
        failures,
    )

    prepare = (ROOT / "build/panther/prepare-r8-final-ui.sh").read_text(
        encoding="utf-8"
    )
    for token in (
        "apply_r9_launcher3_foundation.py",
        'python3 "$R9_LAUNCHER3" --source "$WS" apply',
        'python3 "$R9_LAUNCHER3" --source "$WS" verify',
        "R9_LAUNCHER3_FOUNDATION_PREPARE=PASS",
    ):
        require(prepare, token, "Panther preparation", failures)

    build = (ROOT / "build/panther/build-r8-final-ui.sh").read_text(
        encoding="utf-8"
    )
    for token in (
        "===== LAUNCHER3 QUICKSTEP SOONG PREFLIGHT =====",
        'm -j"$JOBS" Launcher3QuickStep',
        "R9_LAUNCHER3_QUICKSTEP_SOONG_PREFLIGHT=PASS",
        "FAIL_LAUNCHER3_FOUNDATION_PREFLIGHT",
    ):
        require(build, token, "Panther focused build gate", failures)
    forbid(
        build,
        'm -j"$JOBS" SableStart',
        "standalone SableStart Soong build",
        failures,
    )
    forbid(
        build,
        "r8-sablestart-signing-policy.py",
        "retired SableStart APK signing gate",
        failures,
    )

    target_gate = (
        ROOT / "build/gates/r8-final-target-files.sh"
    ).read_text(encoding="utf-8")
    for token in (
        'matches("Launcher3QuickStep.apk")',
        'matches("SableStart.apk")',
        "R9_STANDALONE_SABLESTART_TARGET=PASS_ABSENT",
        "[Launcher3QuickStep.apk]=com.android.launcher3",
        "R9_L7_LAUNCHER3_FOUNDATION_TARGET_FILES=PASS",
    ):
        require(target_gate, token, "target-files launcher gate", failures)

    composition = (
        ROOT / "build/gates/r8-final-product-composition.sh"
    ).read_text(encoding="utf-8")
    for token in (
        "===== R9 LAUNCHER3 / QUICKSTEP FOUNDATION VERIFY =====",
        "apply_r9_launcher3_foundation.py",
        "R9_LAUNCHER3_FOUNDATION=PASS",
        "r9-launcher3-foundation-contract.py",
    ):
        require(composition, token, "product composition", failures)

    sync = (ROOT / "build/panther/sync-sablestart.sh").read_text(
        encoding="utf-8"
    )
    for token in (
        "src/com/sable/start/ui/SableStartScreen.kt",
        "src/com/sable/start/platform/SableAppearanceProvider.kt",
    ):
        require(sync, token, "presentation sync", failures)
    for token in (
        "SableStartActivity.kt",
        "LauncherAppsRepository.kt",
        "rust/src/lib.rs",
        "AndroidManifest.xml",
    ):
        forbid(sync, token, "presentation-only sync", failures)

    check_gradle = (
        ROOT / "apps/r8/android/sablestart-production-check/build.gradle.kts"
    ).read_text(encoding="utf-8")
    require(
        check_gradle,
        'manifest.srcFile("src/main/AndroidManifest.xml")',
        "presentation CI manifest",
        failures,
    )
    forbid(
        check_gradle,
        "src/android/packages/apps/SableStart/AndroidManifest.xml",
        "retired standalone manifest in CI",
        failures,
    )
    forbid(
        check_gradle,
        "androidx.activity:activity-compose",
        "retired ComponentActivity/BackHandler dependency",
        failures,
    )

    return failures


def self_test() -> None:
    failures: list[str] = []
    require("abc", "a", "require-positive", failures)
    forbid("abc", "z", "forbid-positive", failures)
    assert not failures

    failures = []
    require("abc", "z", "require-negative", failures)
    forbid("abc", "a", "forbid-negative", failures)
    assert len(failures) == 2

    print("R9_LAUNCHER3_FOUNDATION_CONTRACT_SELF_TEST=PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0

    failures = check()
    if failures:
        for item in failures:
            print(f"FAIL: {item}", file=sys.stderr)
        print("R9_LAUNCHER3_FOUNDATION_CONTRACT=FAIL", file=sys.stderr)
        return 1

    print("R9_LAUNCHER3_FOUNDATION_CONTRACT=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
