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
import tempfile

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


def resolve_launcher_root(source: pathlib.Path) -> pathlib.Path:
    workspace_launcher = source / "packages/apps/Launcher3"
    if workspace_launcher.is_dir():
        return workspace_launcher

    # Isolated self-tests and direct developer probes may pass the Launcher3
    # repository itself. Require both canonical top-level markers so an
    # arbitrary non-git directory is not misclassified.
    if (source / "Android.bp").is_file() and (source / "quickstep").is_dir():
        return source

    raise RecentsOnlyError(
        "Launcher3 source root unresolved: "
        f"source={source} expected={workspace_launcher}"
    )


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
    ],'''
    new = '''    kotlincflags: [
        "-Xjvm-default=all",
        "-Xannotation-default-target=param-property",
    ],'''
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

    # ResolveInfo remains required by the secondary-home path below this
    # constructor. Only the primary-home ResolveInfo use is retired.
    if "import android.content.pm.ResolveInfo;\n" not in text:
        raise RecentsOnlyError(
            "Overview ResolveInfo import missing for retained secondary-home path"
        )
    if "ResolveInfo secondaryInfo =" not in text:
        raise RecentsOnlyError(
            "Overview retained secondary-home ResolveInfo path missing"
        )
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
        "import android.content.pm.ResolveInfo;",
        "ResolveInfo secondaryInfo =",
    ):
        if token not in observer:
            raise RecentsOnlyError(f"recents-only observer contract missing: {token}")

    print("R9_SABLE_LAUNCHER3_HOST=PASS_ABSENT")
    print("R9_LAUNCHER3_HOME_ELIGIBILITY=PASS_ABSENT")
    print("R9_LAUNCHER3_PRIVATE_ACTIVITY=PASS_INTERNAL_ONLY")
    print("R9_QUICKSTEP_SERVICE=PASS_RETAINED")
    print("R9_FALLBACK_RECENTS=PASS_RETAINED")
    print("R9_QUICKSTEP_RECENTS_ONLY=PASS")


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="r9_quickstep_recents_") as raw:
        root = pathlib.Path(raw)
        (root / "quickstep").mkdir(parents=True)
        (root / "quickstep/src/com/android/quickstep").mkdir(parents=True)
        (root / "quickstep/src/com/android/launcher3/uioverrides/touchcontrollers").mkdir(
            parents=True
        )

        bp = """android_library {
    name: "Launcher3QuickStepLib",
    kotlincflags: [
        "-Xjvm-default=all",
    ],
}

// Build rule for Quickstep app.
"""
        manifest = """<manifest>
    <application>
        <activity
            android:name="com.android.launcher3.uioverrides.QuickstepLauncher"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <action android:name="android.intent.action.ALL_APPS" />
                <category android:name="android.intent.category.HOME" />
            </intent-filter>
        </activity>
    </application>
</manifest>
"""
        observer = """import android.content.pm.ResolveInfo;
import com.android.launcher3.util.DaggerSingletonTracker;
        mMyPrimaryHomeIntent = new Intent(mCurrentPrimaryHomeIntent).setPackage(
                context.getPackageName());
        ResolveInfo info = context.getPackageManager().resolveActivity(mMyPrimaryHomeIntent, 0);
        ComponentName myHomeComponent =
                new ComponentName(context.getPackageName(), info.activityInfo.name);
        mMyPrimaryHomeIntent.setComponent(myHomeComponent);

        mConfigChangesMap.append(myHomeComponent.hashCode(), info.activityInfo.configChanges);

        ResolveInfo secondaryInfo = mContext.getPackageManager().resolveActivity(
                mLazySecondaryHomeIntent, 0);
"""
        (root / "Android.bp").write_text(bp, encoding="utf-8")
        if resolve_launcher_root(root) != root:
            raise RecentsOnlyError("self-test direct Launcher3 root resolution failed")

        workspace = root / "workspace"
        nested = workspace / "packages/apps/Launcher3"
        nested.mkdir(parents=True)
        (nested / "Android.bp").write_text(bp, encoding="utf-8")
        (nested / "quickstep").mkdir(exist_ok=True)
        if resolve_launcher_root(workspace) != nested:
            raise RecentsOnlyError("self-test workspace Launcher3 root resolution failed")

        try:
            resolve_launcher_root(root / "missing")
        except RecentsOnlyError:
            pass
        else:
            raise RecentsOnlyError("self-test unresolved source did not fail closed")

        print("R9_QUICKSTEP_RECENTS_ONLY_SOURCE_RESOLUTION_SELF_TEST=PASS")
        (root / "quickstep/AndroidManifest-launcher.xml").write_text(
            manifest, encoding="utf-8"
        )
        observer_path = (
            root / "quickstep/src/com/android/quickstep/OverviewComponentObserver.java"
        )
        observer_path.write_text(observer, encoding="utf-8")

        patch_android_bp(root)
        patch_launcher_manifest(root)
        patch_overview_observer(root)

        first_pass_bp = (root / "Android.bp").read_text(encoding="utf-8")
        patch_android_bp(root)
        second_pass_bp = (root / "Android.bp").read_text(encoding="utf-8")
        if second_pass_bp != first_pass_bp:
            raise RecentsOnlyError("self-test Android.bp patch is not idempotent")

        patched_bp = second_pass_bp
        patched_manifest = (
            root / "quickstep/AndroidManifest-launcher.xml"
        ).read_text(encoding="utf-8")
        patched_observer = observer_path.read_text(encoding="utf-8")

        if "-Xannotation-default-target=param-property" not in patched_bp:
            raise RecentsOnlyError("self-test Kotlin compatibility flag missing")
        if 'android:exported="false"' not in patched_manifest:
            raise RecentsOnlyError("self-test private activity marker missing")
        if "android.intent.category.HOME" in patched_manifest:
            raise RecentsOnlyError("self-test HOME filter survived")
        if "new ComponentName(context, QuickstepLauncher.class)" not in patched_observer:
            raise RecentsOnlyError("self-test explicit Quickstep component missing")
        if "resolveActivity(mMyPrimaryHomeIntent" in patched_observer:
            raise RecentsOnlyError("self-test old own-HOME resolution survived")
        if "import android.content.pm.ResolveInfo;" not in patched_observer:
            raise RecentsOnlyError("self-test retained ResolveInfo import missing")
        if "ResolveInfo secondaryInfo =" not in patched_observer:
            raise RecentsOnlyError(
                "self-test retained secondary-home ResolveInfo use missing"
            )

        print("R9_QUICKSTEP_RESOLVEINFO_SECONDARY_HOME_SELF_TEST=PASS")

    print("R9_QUICKSTEP_RECENTS_ONLY_SELF_TEST=PASS")


def apply(root: pathlib.Path) -> None:
    require_head(root)
    restore_pinned_scope(root)
    patch_android_bp(root)
    patch_launcher_manifest(root)
    patch_overview_observer(root)
    verify(root)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=pathlib.Path)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("mode", nargs="?", choices=("apply", "verify"))
    args = parser.parse_args()

    if args.self_test:
        if args.source is not None or args.mode is not None:
            parser.error("--self-test cannot be combined with --source or mode")
        self_test()
        return 0

    if args.source is None or args.mode is None:
        parser.error("--source and mode are required")

    source = args.source.resolve()
    root = resolve_launcher_root(source)
    print(f"R9_QUICKSTEP_RECENTS_ONLY_LAUNCHER_ROOT={root}")
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
