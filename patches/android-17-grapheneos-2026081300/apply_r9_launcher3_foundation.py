#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import shutil
import subprocess
import sys
import tempfile

LAUNCHER3_HEAD = "e5fde8f4368539554b07ee136abd27bc7b4284c1"
HOST_REL = pathlib.Path(
    "quickstep/src/com/android/launcher3/sable/SableQuickstepLauncher.kt"
)

ROOT = pathlib.Path(__file__).resolve().parents[2]
HOST_SOURCE = (
    ROOT
    / "patches"
    / "android-17-grapheneos-2026081300"
    / "r9_launcher3"
    / "SableQuickstepLauncher.kt"
)

BP_SRC_ANCHOR = '''        ":launcher-quickstep-dagger",
        ":launcher-build-config",
'''
BP_SRC_REPLACEMENT = '''        ":launcher-quickstep-dagger",
        ":launcher-build-config",
        ":sable_start_presentation_srcs",
        ":sable_design_shared_srcs",
'''

BP_LIB_ANCHOR = '''        "SystemUI-statsd",
        "QuickstepResLib",
        // Compose dep
'''
BP_LIB_REPLACEMENT = '''        "SystemUI-statsd",
        "QuickstepResLib",
        "androidx.compose.foundation_foundation",
        "androidx.compose.foundation_foundation-layout",
        "androidx.compose.animation_animation",
        "androidx.compose.ui_ui",
        "androidx.compose.material3_material3",
        "androidx.core_core-ktx",
        "kotlinx_coroutines_android",
        // Compose dep
'''

MANIFEST_HEADER = '''<manifest
    xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.android.launcher3">
'''
MANIFEST_HEADER_REPLACEMENT = MANIFEST_HEADER + '''
    <uses-permission android:name="android.permission.READ_CALENDAR" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
    <uses-permission
        android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
'''

ACTIVITY_OLD = (
    'android:name="com.android.launcher3.uioverrides.QuickstepLauncher"'
)
ACTIVITY_NEW = (
    'android:name="com.android.launcher3.sable.SableQuickstepLauncher"'
)

PROVIDER_ANCHOR = '''        <!--
        Main launcher activity. When extending only change the name, and keep all the
'''
PROVIDER_BLOCK = '''        <provider
            android:name="org.sableos.start.platform.SableAppearanceProvider"
            android:authorities="org.sableos.start.appearance"
            android:exported="true"
            android:grantUriPermissions="false" />

''' + PROVIDER_ANCHOR

LABEL_OLD = (
    '<string name="derived_app_name" translatable="false">Launcher</string>'
)
LABEL_NEW = (
    '<string name="derived_app_name" translatable="false">Sable Start</string>'
)


class FoundationError(RuntimeError):
    pass


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise FoundationError(
            f"{label}: expected exactly one anchor, found {count}"
        )
    return text.replace(old, new, 1)


def launcher3_module_slice(text: str) -> tuple[int, int, str]:
    marker = 'android_library {\n    name: "Launcher3QuickStepLib",'
    start = text.find(marker)
    if start < 0:
        raise FoundationError("Launcher3QuickStepLib module missing")
    end_marker = "\n}\n\n// Build rule for Quickstep app."
    end = text.find(end_marker, start)
    if end < 0:
        raise FoundationError("Launcher3QuickStepLib end marker missing")
    end += 2
    return start, end, text[start:end]


def patch_android_bp(text: str) -> str:
    start, end, module = launcher3_module_slice(text)
    module = replace_once(
        module,
        BP_SRC_ANCHOR,
        BP_SRC_REPLACEMENT,
        "Launcher3QuickStepLib sources",
    )
    module = replace_once(
        module,
        BP_LIB_ANCHOR,
        BP_LIB_REPLACEMENT,
        "Launcher3QuickStepLib Compose dependencies",
    )
    return text[:start] + module + text[end:]


def patch_manifest(text: str) -> str:
    text = replace_once(
        text,
        MANIFEST_HEADER,
        MANIFEST_HEADER_REPLACEMENT,
        "Quickstep manifest permissions",
    )
    text = replace_once(
        text,
        PROVIDER_ANCHOR,
        PROVIDER_BLOCK,
        "Quickstep Sable appearance provider",
    )
    text = replace_once(
        text,
        ACTIVITY_OLD,
        ACTIVITY_NEW,
        "Quickstep HOME activity",
    )
    return text


def patch_strings(text: str) -> str:
    return replace_once(
        text,
        LABEL_OLD,
        LABEL_NEW,
        "Quickstep product label",
    )


def git_head(path: pathlib.Path) -> str:
    proc = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "HEAD"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        raise FoundationError(
            f"cannot resolve Launcher3 HEAD: {proc.stderr.strip()}"
        )
    return proc.stdout.strip()


def require_workspace_sources(source: pathlib.Path) -> None:
    start_bp = source / "packages/apps/SableStart/Android.bp"
    design_bp = source / "packages/apps/SableDesign/Android.bp"

    if not start_bp.is_file():
        raise FoundationError(f"missing Sable presentation filegroup: {start_bp}")
    if not design_bp.is_file():
        raise FoundationError(f"missing Sable design filegroup: {design_bp}")

    start_text = start_bp.read_text(encoding="utf-8")
    design_text = design_bp.read_text(encoding="utf-8")

    if 'name: "sable_start_presentation_srcs"' not in start_text:
        raise FoundationError("sable_start_presentation_srcs filegroup missing")
    if "android_app {" in start_text or "rust_ffi_shared {" in start_text:
        raise FoundationError(
            "standalone SableStart app/JNI definition must be retired"
        )
    if 'name: "sable_design_shared_srcs"' not in design_text:
        raise FoundationError("sable_design_shared_srcs filegroup missing")


def verify_tree(source: pathlib.Path, *, check_head: bool = True) -> None:
    launcher = source / "packages/apps/Launcher3"
    if not launcher.is_dir():
        raise FoundationError(f"Launcher3 tree missing: {launcher}")

    if check_head:
        head = git_head(launcher)
        if head != LAUNCHER3_HEAD:
            raise FoundationError(
                f"Launcher3 HEAD mismatch expected={LAUNCHER3_HEAD} actual={head}"
            )

    require_workspace_sources(source)

    bp = (launcher / "Android.bp").read_text(encoding="utf-8")
    manifest = (
        launcher / "quickstep/AndroidManifest-launcher.xml"
    ).read_text(encoding="utf-8")
    strings = (
        launcher / "quickstep/res/values/strings.xml"
    ).read_text(encoding="utf-8")
    host_path = launcher / HOST_REL

    _, _, module = launcher3_module_slice(bp)
    for token in (
        '":sable_start_presentation_srcs",',
        '":sable_design_shared_srcs",',
        '"androidx.compose.foundation_foundation",',
        '"androidx.compose.foundation_foundation-layout",',
        '"androidx.compose.animation_animation",',
        '"androidx.compose.ui_ui",',
        '"androidx.compose.material3_material3",',
        '"androidx.core_core-ktx",',
        '"kotlinx_coroutines_android",',
    ):
        if token not in module:
            raise FoundationError(f"Launcher3QuickStepLib token missing: {token}")

    for token in (
        ACTIVITY_NEW,
        "android.permission.READ_CALENDAR",
        "android.permission.READ_MEDIA_IMAGES",
        "android.permission.READ_MEDIA_AUDIO",
        'android:authorities="org.sableos.start.appearance"',
        'android:name="org.sableos.start.platform.SableAppearanceProvider"',
    ):
        if token not in manifest:
            raise FoundationError(f"Quickstep manifest token missing: {token}")

    if ACTIVITY_OLD in manifest:
        raise FoundationError("upstream QuickstepLauncher remains the HOME component")

    if LABEL_NEW not in strings:
        raise FoundationError("Sable Start product label missing")

    if not host_path.is_file():
        raise FoundationError(f"Sable Quickstep host missing: {host_path}")
    if host_path.read_bytes() != HOST_SOURCE.read_bytes():
        raise FoundationError("Sable Quickstep host differs from canonical source")

    host = host_path.read_text(encoding="utf-8")
    required_host_tokens = (
        "class SableQuickstepLauncher : QuickstepLauncher()",
        "activityComponent.appsStore",
        "store.addUpdateListener(appsUpdateListener)",
        "startActivitySafely(",
        "PackageManagerHelper.startDetailsActivityForInfo(",
        "override fun onStateSetStart(state: LauncherState)",
        "override fun onStateSetEnd(state: LauncherState)",
        "protected override fun getOnBackAnimationCallback()",
        "SableStartScreen(",
        "homeGeneration = homeGeneration.value",
        "backGeneration = backGeneration.value",
    )
    for token in required_host_tokens:
        if token not in host:
            raise FoundationError(f"Sable Quickstep host token missing: {token}")


def apply_tree(source: pathlib.Path) -> None:
    launcher = source / "packages/apps/Launcher3"
    if git_head(launcher) != LAUNCHER3_HEAD:
        raise FoundationError(
            "refusing Launcher3 mutation because the pinned base HEAD differs"
        )

    require_workspace_sources(source)

    bp_path = launcher / "Android.bp"
    manifest_path = launcher / "quickstep/AndroidManifest-launcher.xml"
    strings_path = launcher / "quickstep/res/values/strings.xml"
    host_path = launcher / HOST_REL

    bp_path.write_text(
        patch_android_bp(bp_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    manifest_path.write_text(
        patch_manifest(manifest_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    strings_path.write_text(
        patch_strings(strings_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )

    host_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(HOST_SOURCE, host_path)

    verify_tree(source)


def self_test() -> None:
    bp = '''prefix
android_library {
    name: "Launcher3QuickStepLib",
    srcs: [
        ":launcher-src",
        ":launcher-quickstep-src",
        ":launcher-quickstep-dagger",
        ":launcher-build-config",
    ],
    static_libs: [
        "SystemUI-statsd",
        "QuickstepResLib",
        // Compose dep
        "androidx.compose.runtime_runtime",
    ],
}

// Build rule for Quickstep app.
suffix
'''
    patched_bp = patch_android_bp(bp)
    assert patch_android_bp(patched_bp) == patched_bp
    assert '":sable_start_presentation_srcs",' in patched_bp
    assert '"androidx.compose.foundation_foundation",' in patched_bp

    manifest = MANIFEST_HEADER + '''
    <application>
''' + PROVIDER_ANCHOR + '''
        <activity
            ''' + ACTIVITY_OLD + ''' />
    </application>
</manifest>
'''
    patched_manifest = patch_manifest(manifest)
    assert patch_manifest(patched_manifest) == patched_manifest
    assert ACTIVITY_NEW in patched_manifest
    assert ACTIVITY_OLD not in patched_manifest
    assert "org.sableos.start.appearance" in patched_manifest

    strings = "<resources>\n    " + LABEL_OLD + "\n</resources>\n"
    patched_strings = patch_strings(strings)
    assert patch_strings(patched_strings) == patched_strings
    assert LABEL_NEW in patched_strings

    try:
        replace_once("x", "missing", "new", "negative")
    except FoundationError:
        pass
    else:
        raise AssertionError("missing anchor did not fail closed")

    print("R9_LAUNCHER3_FOUNDATION_SELF_TEST=PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=pathlib.Path)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("action", nargs="?", choices=("apply", "verify"))
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0

    if args.source is None or args.action is None:
        parser.error("--source and action are required unless --self-test is used")

    source = args.source.resolve()

    try:
        if args.action == "apply":
            apply_tree(source)
            print("R9_LAUNCHER3_FOUNDATION_APPLY=PASS")
        else:
            verify_tree(source)
            print("R9_LAUNCHER3_FOUNDATION_VERIFY=PASS")
    except FoundationError as exc:
        print(f"R9_LAUNCHER3_FOUNDATION=FAIL {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
