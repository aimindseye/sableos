#!/usr/bin/env python3
"""Convert the pinned Launcher3QuickStep package into a recents-only substrate.

R9 SableLauncher owns HOME. Launcher3QuickStep retains TouchInteractionService,
RecentsActivity and its private QuickstepLauncher implementation because the
upstream Quickstep stack uses that component internally for configuration
bookkeeping. The activity no longer advertises HOME/ALL_APPS/MAIN and is not
exported, so native Launcher3 workspace is not a user-resolvable launcher.
"""

from __future__ import annotations

import argparse
import pathlib
import subprocess

LAUNCHER3_HEAD = "e5fde8f4368539554b07ee136abd27bc7b4284c1"

RESTORE_FROM_PIN = (
    "Android.bp",
    "quickstep/AndroidManifest-launcher.xml",
    "quickstep/AndroidManifest.xml",
    "quickstep/res/values/strings.xml",
    "quickstep/src/com/android/launcher3/uioverrides/touchcontrollers/"
    "PortraitStatesTouchController.java",
    "quickstep/src/com/android/launcher3/uioverrides/touchcontrollers/"
    "NoButtonNavbarToOverviewTouchController.java",
    "quickstep/src/com/android/quickstep/OverviewComponentObserver.java",
)

SABLE_HOST = pathlib.Path(
    "quickstep/src/com/android/launcher3/sable/SableQuickstepLauncher.kt"
)


class RecentsOnlyError(RuntimeError):
    pass


def git(root: pathlib.Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(root), *args],
        text=True,
        stderr=subprocess.STDOUT,
    )


def require_head(root: pathlib.Path) -> None:
    actual = git(root, "rev-parse", "HEAD").strip()
    if actual != LAUNCHER3_HEAD:
        raise RecentsOnlyError(
            f"Launcher3 baseline mismatch expected={LAUNCHER3_HEAD} actual={actual}"
        )


def pinned_text(root: pathlib.Path, rel: str) -> str:
    return git(root, "show", f"{LAUNCHER3_HEAD}:{rel}")


def restore_pinned_scope(root: pathlib.Path) -> None:
    for rel in RESTORE_FROM_PIN:
        path = root / rel
        expected = pinned_text(root, rel)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(expected, encoding="utf-8")

    host = root / SABLE_HOST
    if host.exists():
        host.unlink()
    if host.parent.is_dir() and not any(host.parent.iterdir()):
        host.parent.rmdir()


def patch_android_bp(root: pathlib.Path) -> None:
    path = root / "Android.bp"
    text = path.read_text(encoding="utf-8")
    module_marker = 'android_library {\n    name: "Launcher3QuickStepLib",'
    start = text.find(module_marker)
    if start < 0:
        raise RecentsOnlyError("Launcher3QuickStepLib missing")
    end = text.find("\n}\n\n// Build rule for Quickstep app.", start)
    if end < 0:
        raise RecentsOnlyError("Launcher3QuickStepLib end marker missing")
    module = text[start:end]
    old = '''    kotlincflags: [
        "-Xjvm-default=all",
    ],
'''
    new = '''    kotlincflags: [
        "-Xjvm-default=all",
        "-Xannotation-default-target=param-property",
    ],
'''
    if new not in module:
        if module.count(old) != 1:
            raise RecentsOnlyError("Quickstep Kotlin flags anchor changed")
        module = module.replace(old, new, 1)
    path.write_text(text[:start] + module + text[end:], encoding="utf-8")


def patch_launcher_manifest(root: pathlib.Path) -> None:
    path = root / "quickstep/AndroidManifest-launcher.xml"
    text = path.read_text(encoding="utf-8")
    activity_start = text.find(
        '        <activity\n'
        '            android:name="com.android.launcher3.uioverrides.QuickstepLauncher"'
    )
    if activity_start < 0:
        raise RecentsOnlyError("QuickstepLauncher activity missing")
    activity_end = text.find("        </activity>", activity_start)
    if activity_end < 0:
        raise RecentsOnlyError("QuickstepLauncher activity end missing")
    activity_end += len("        </activity>")
    activity = text[activity_start:activity_end]

    filter_start = activity.find("            <intent-filter>")
    filter_end = activity.find("            </intent-filter>")
    if filter_start < 0 or filter_end < 0:
        raise RecentsOnlyError("QuickstepLauncher HOME filter missing")
    filter_end += len("            </intent-filter>")
    activity = activity[:filter_start] + activity[filter_end:]
    activity = activity.replace(
        'android:exported="true"',
        'android:exported="false"',
        1,
    )
    text = text[:activity_start] + activity + text[activity_end:]
    path.write_text(text, encoding="utf-8")


def patch_overview_observer(root: pathlib.Path) -> None:
    path = root / "quickstep/src/com/android/quickstep/OverviewComponentObserver.java"
    text = path.read_text(encoding="utf-8")

    import_anchor = "import com.android.launcher3.util.DaggerSingletonTracker;\n"
    import_line = "import com.android.launcher3.uioverrides.QuickstepLauncher;\n"
    if import_line not in text:
        if import_anchor not in text:
            raise RecentsOnlyError("Overview QuickstepLauncher import anchor changed")
        text = text.replace(
            import_anchor,
            import_anchor + import_line,
            1,
        )

    old = '''        mMyPrimaryHomeIntent = new Intent(mCurrentPrimaryHomeIntent).setPackage(
                context.getPackageName());
        ResolveInfo info = context.getPackageManager().resolveActivity(mMyPrimaryHomeIntent, 0);
        ComponentName myHomeComponent =
                new ComponentName(context.getPackageName(), info.activityInfo.name);
        mMyPrimaryHomeIntent.setComponent(myHomeComponent);

        mConfigChangesMap.append(myHomeComponent.hashCode(), info.activityInfo.configChanges);
'''
    new = '''        // SableOS R9: Launcher3 is not a HOME candidate. Keep its launcher
        // activity private for Quickstep configuration bookkeeping while the
        // system default HOME resolves exclusively to org.sableos.launcher.
        ComponentName myHomeComponent = new ComponentName(context, QuickstepLauncher.class);
        mMyPrimaryHomeIntent = new Intent(mCurrentPrimaryHomeIntent)
                .setComponent(myHomeComponent);
        try {
            ActivityInfo info = context.getPackageManager().getActivityInfo(
                    myHomeComponent, 0 /* flags */);
            mConfigChangesMap.append(myHomeComponent.hashCode(), info.configChanges);
        } catch (PackageManager.NameNotFoundException e) {
            throw new IllegalStateException("Private QuickstepLauncher activity missing", e);
        }
'''
    if new not in text:
        if text.count(old) != 1:
            raise RecentsOnlyError("Overview own-HOME resolution anchor changed")
        text = text.replace(old, new, 1)

    # ResolveInfo is no longer needed by this constructor path.
    text = text.replace("import android.content.pm.ResolveInfo;\n", "")
    path.write_text(text, encoding="utf-8")


def verify(root: pathlib.Path) -> None:
    require_head(root)

    bp = (root / "Android.bp").read_text(encoding="utf-8")
    manifest = (
        root / "quickstep/AndroidManifest-launcher.xml"
    ).read_text(encoding="utf-8")
    quickstep_manifest = (
        root / "quickstep/AndroidManifest.xml"
    ).read_text(encoding="utf-8")
    observer = (
        root / "quickstep/src/com/android/quickstep/OverviewComponentObserver.java"
    ).read_text(encoding="utf-8")

    forbidden = (
        ":sable_start_presentation_srcs",
        ":sable_design_shared_srcs",
        "com.android.launcher3.sable.SableQuickstepLauncher",
        "org.sableos.appearance",
        "org.sableos.weather.snapshot",
        "org.sableos.calendar.snapshot",
        "org.sableos.hub.snapshot",
        "org.sableos.mail.snapshot",
        "org.sableos.media.snapshot",
    )
    joined = bp + manifest + quickstep_manifest
    for token in forbidden:
        if token in joined:
            raise RecentsOnlyError(f"Sable Launcher3 host residue remains: {token}")

    if (root / SABLE_HOST).exists():
        raise RecentsOnlyError("SableQuickstepLauncher source still present")

    activity_start = manifest.find(
        'android:name="com.android.launcher3.uioverrides.QuickstepLauncher"'
    )
    activity_end = manifest.find("</activity>", activity_start)
    if activity_start < 0 or activity_end < 0:
        raise RecentsOnlyError("private QuickstepLauncher activity missing")
    activity = manifest[activity_start:activity_end]
    for token in (
        'android.intent.category.HOME',
        'android.intent.action.ALL_APPS',
        'android.intent.action.SHOW_WORK_APPS',
        '<intent-filter>',
    ):
        if token in activity:
            raise RecentsOnlyError(f"QuickstepLauncher still user-resolvable: {token}")
    if 'android:exported="false"' not in activity:
        raise RecentsOnlyError("QuickstepLauncher is not private")

    for token in (
        'android.intent.action.QUICKSTEP_SERVICE',
        'com.android.quickstep.TouchInteractionService',
        'com.android.quickstep.RecentsActivity',
    ):
        if token not in quickstep_manifest:
            raise RecentsOnlyError(f"Quickstep substrate missing: {token}")

    for token in (
        "new ComponentName(context, QuickstepLauncher.class)",
        "getActivityInfo(",
        "Private QuickstepLauncher activity missing",
    ):
        if token not in observer:
            raise RecentsOnlyError(f"recents-only observer contract missing: {token}")

    print("R9_SABLE_LAUNCHER3_HOST=PASS_ABSENT")
    print("R9_LAUNCHER3_HOME_ELIGIBILITY=PASS_ABSENT")
    print("R9_LAUNCHER3_PRIVATE_ACTIVITY=PASS_INTERNAL_ONLY")
    print("R9_QUICKSTEP_SERVICE=PASS_RETAINED")
    print("R9_FALLBACK_RECENTS=PASS_RETAINED")
    print("R9_QUICKSTEP_RECENTS_ONLY=PASS")


def apply(root: pathlib.Path) -> None:
    require_head(root)
    restore_pinned_scope(root)
    patch_android_bp(root)
    patch_launcher_manifest(root)
    patch_overview_observer(root)
    verify(root)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=pathlib.Path)
    parser.add_argument("mode", choices=("apply", "verify"))
    args = parser.parse_args()
    root = args.source.resolve()
    if args.mode == "apply":
        apply(root)
    else:
        verify(root)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RecentsOnlyError, subprocess.CalledProcessError) as error:
        print(f"R9_QUICKSTEP_RECENTS_ONLY=FAIL {error}")
        raise SystemExit(1)
