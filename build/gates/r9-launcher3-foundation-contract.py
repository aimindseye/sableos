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

    # Phase 2: SableStart is presentation-only. Launcher3QuickStep is the sole
    # HOME implementation; standalone app/JNI/runtime sources must be absent.
    for token in (
        "android_app {",
        "rust_ffi_shared {",
        'name: "SableStart"',
        'name: "libsable_start_core_jni"',
    ):
        forbid(start_bp, token, "standalone SableStart Soong runtime", failures)

    for rel in (
        "AndroidManifest.xml",
        "res/values/strings.xml",
        "rust/src/lib.rs",
        "src/com/sable/start/SableStartActivity.kt",
        "src/com/sable/start/bridge/SableStartNative.kt",
        "src/com/sable/start/platform/LauncherAppsRepository.kt",
    ):
        if (start_root / rel).exists():
            failures.append(f"standalone SableStart runtime source remains: {rel}")

    product_mk = (ROOT / "product/r8/panther/r8-product.mk").read_text(encoding="utf-8")
    forbid(product_mk, "    SableStart \\", "standalone SableStart product module", failures)

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

    system_bars = (
        ROOT
        / "src/android/shared/sabledesign/src/main/java/org/sableos/design/SableSystemBars.kt"
    ).read_text(encoding="utf-8")
    forbid(system_bars, "statusBarColor", "deprecated status bar color API", failures)
    forbid(
        system_bars,
        "navigationBarColor",
        "deprecated navigation bar color API",
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
        "removeUpdateListener(appsUpdateListener)",
        "startActivitySafely(",
        "PackageManagerHelper.startDetailsActivityForInfo(",
        "override fun onStateSetStart(state: LauncherState)",
        "override fun onStateSetEnd(state: LauncherState)",
        "protected override fun getOnBackAnimationCallback()",
        "SableStartScreen(",
        "homeGeneration = homeGeneration.value",
        "backGeneration = backGeneration.value",
        "updateSableVisibility(isInState(LauncherState.NORMAL))",
        "val activityWindow = window ?: return",
        "window = activityWindow",
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
            "KNOWN_LEGACY_FALLBACK_BLOB",
            "KNOWN_LEGACY_FALLBACK_TEST_BLOB",
            "normalize_known_legacy_residue",
            "validate_preexisting_fallback_compat",
            "R9_LAUNCHER3_DIRTY_PATHS=PASS",
            "R9_LAUNCHER3_FALLBACK_NULL_CALLBACK_COMPAT=PASS",
            "R9_LAUNCHER3_WARNING_CLEANUP_SAFE_MIGRATIONS=PASS",
            "-Xannotation-default-target=param-property",
            "patch_user_cache",
            "patch_retrying_executor",
            "patch_widget_size_handler",
            "patch_preview_context",
            "patch_preview_lifecycle",
            "patch_wallpaper_theme_manager",
            "patch_double_shadow_icon_drawable",
            "patch_item_info_translators",
            "patch_utilities_kt",
            "patch_cacheable_shortcut",
            "patch_display_info_container",
            "patch_model_writer",
            "patch_fake_model_writer",
            "patch_desktop_visibility",
            "patch_overflown_apps",
            "patch_bubble_bar_background",
            "patch_phone_landscape_nav",
            "patch_stats_log_compat",
            "patch_seascape_handler",
            "patch_group_task",
            "patch_desktop_task_view",
            "patch_floating_app_pair_background",
            "patch_preload_icon_delegate",
            "patch_db_entry",
            "patch_add_item_activity",
            "patch_display_controller_impl",
            "patch_taskbar_device_profile_factory",
            "patch_widget_app_icons_repository",
            "patch_wallpaper_color_hints",
            "patch_first_screen_broadcast_helper",
            "patch_model_task_controller",
            "patch_refresh_rate_tracker",
            "patch_remove_animation_settings_tracker",
            "R9_LAUNCHER3_DAGGER_EASY_EXECUTOR_MIGRATION=PASS",
            "R9_LAUNCHER3_FOUNDATION_VERIFY=PASS",
            "HOME_OWNERSHIP_CUTOVER",
            "R9_SABLESTART_STANDALONE_RUNTIME=PASS_ABSENT",
            "R9_LAUNCHER3_HOME_OWNERSHIP=PASS",
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

    warning_gate = ROOT / "build/gates/r9-launcher-warning-gate.py"
    if not warning_gate.is_file():
        failures.append("Launcher3 warning gate missing")
    else:
        warning_text = warning_gate.read_text(encoding="utf-8")
        for token in (
            "R9_LAUNCHER3_WARNING_GATE_SELF_TEST=PASS",
            "R9_LAUNCHER3_WARNING_COUNT",
            "R9_LAUNCHER3_DEPRECATION_COUNT",
            "R9_LAUNCHER3_UPSTREAM_DEPRECATION_DEBT",
            "R9_LAUNCHER3_SABLE_WARNING_COUNT=0",
            "R9_LAUNCHER3_WARNING_MIGRATION_GATE=PASS",
            "R9_LAUNCHER3_R8_API37_DEBT",
            "R9_LAUNCHER3_WARNING_DEBT_STATUS",
            "R9_LAUNCHER3_WARNING_GATE=PASS",
            "GLOBAL_MIGRATED_WARNING_MARKERS",
            "MIGRATED_WARNING_RULES",
        ):
            require(warning_text, token, "Launcher3 warning gate", failures)

        proc = subprocess.run(
            [sys.executable, str(warning_gate), "--self-test"],
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
            failures.append("Launcher3 warning gate self-test failed")

    qualifier = ROOT / "build/panther/qualify-r9-launcher3-foundation.sh"
    if not qualifier.is_file():
        failures.append("focused Launcher3 qualifier missing")
    else:
        q = qualifier.read_text(encoding="utf-8")
        for token in (
            'source "$ROOT/build/config/r8-release.env"',
            'source "$ROOT/build/config/panther-grapheneos-2026081300.env"',
            'OUT_DIR="${OUT_DIR:-$SABLE_R8_OUT_DIR}"',
            'ALLOW_COLD_OUT="${ALLOW_COLD_OUT:-NO}"',
            "collect_ninja_graphs",
            "build-*panther*.ninja",
            "combined-*panther*.ninja",
            "R9_LAUNCHER3_FOUNDATION_NINJA_GRAPH",
            "R9_LAUNCHER3_FOUNDATION_COLD_BUILD_REFUSED=YES",
            "R9_LAUNCHER3_FOUNDATION_WARM_OUT=PASS",
            "FULL_IMAGE_BUILD_AUTHORIZED=NO",
            "DEVICE_CONTACT_AUTHORIZED=NO",
            'm -j"$JOBS" Launcher3QuickStep',
            "r9-launcher-warning-gate.py",
            "R9_LAUNCHER3_WARNING_MIGRATIONS=PASS",
            "R9_LAUNCHER3_WARNING_QUALITY=OPEN_DEBT_REMAINS",
            "R9_LAUNCHER3_DAGGER_EASY_EXECUTOR_MIGRATION=PASS",
            "R9_L7_LAUNCHER3_FOUNDATION_COMPILE=PASS",
            "R9_STANDALONE_SABLESTART_PRODUCT=PASS_ABSENT",
            "STANDALONE_SABLESTART_RETIREMENT_AUTHORIZED=YES",
        ):
            require(q, token, "focused Launcher3 qualifier", failures)

    workflows = list((ROOT / ".github/workflows").glob("*.yml"))
    workflows += list((ROOT / ".github/workflows").glob("*.yaml"))
    if workflows:
        failures.append(
            "hosted workflow files reintroduced: "
            + ", ".join(sorted(path.name for path in workflows))
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

    print("R9_LAUNCHER3_PHASE=HOME_OWNERSHIP_CUTOVER")
    print("R9_LAUNCHER3_FOUNDATION_CONTRACT=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
