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

FALLBACK_ACTIVITY_REL = pathlib.Path(
    "quickstep/src/com/android/quickstep/FallbackActivityInterface.java"
)
LEGACY_FALLBACK_TEST_REL = pathlib.Path(
    "quickstep/tests/multivalentTests/src/com/android/quickstep/"
    "FallbackSwipeHandlerTestCase.java"
)

USER_CACHE_REL = pathlib.Path("src/com/android/launcher3/pm/UserCache.kt")
RETRYING_EXECUTOR_REL = pathlib.Path(
    "src/com/android/launcher3/util/RetryingExecutor.kt"
)
WIDGET_SIZE_HANDLER_REL = pathlib.Path(
    "src/com/android/launcher3/widget/util/WidgetSizeHandler.kt"
)
PREVIEW_CONTEXT_REL = pathlib.Path(
    "src/com/android/launcher3/preview/PreviewContext.kt"
)

WALLPAPER_THEME_MANAGER_REL = pathlib.Path(
    "src/com/android/launcher3/util/WallpaperThemeManager.kt"
)
DOUBLE_SHADOW_ICON_DRAWABLE_REL = pathlib.Path(
    "src/com/android/launcher3/views/DoubleShadowIconDrawable.kt"
)
ITEM_INFO_TRANSLATORS_REL = pathlib.Path(
    "src/com/android/launcher3/workspacefunctions/translators/ItemInfoTranslators.kt"
)
UNPLACED_APP_TRANSLATOR_REL = pathlib.Path(
    "src/com/android/launcher3/workspacefunctions/translators/LauncherUnplacedAppTranslator.kt"
)
WORKSPACE_TRANSLATOR_REL = pathlib.Path(
    "src/com/android/launcher3/workspacefunctions/translators/LauncherWorkspaceTypeTranslator.kt"
)

# Observed ai-g732 residue from the prior standalone-HOME debugging session.
# The production blob is retained as an explicit Sable compatibility patch.
# The test blob is known malformed against the pinned Dagger singleton API and
# is normalized back to pinned HEAD before foundation mutation continues.
KNOWN_LEGACY_FALLBACK_BLOB = "8387af17a577a6720cccbc5ca952aefffafa6157"
KNOWN_LEGACY_FALLBACK_TEST_BLOB = "23239ce5180bee05da6ea52afe889e00523619c4"

FOUNDATION_DIRTY_PATHS = {
    "Android.bp",
    "quickstep/AndroidManifest-launcher.xml",
    "quickstep/res/values/strings.xml",
    HOST_REL.as_posix(),
    FALLBACK_ACTIVITY_REL.as_posix(),
    USER_CACHE_REL.as_posix(),
    RETRYING_EXECUTOR_REL.as_posix(),
    WIDGET_SIZE_HANDLER_REL.as_posix(),
    PREVIEW_CONTEXT_REL.as_posix(),
    WALLPAPER_THEME_MANAGER_REL.as_posix(),
    DOUBLE_SHADOW_ICON_DRAWABLE_REL.as_posix(),
    ITEM_INFO_TRANSLATORS_REL.as_posix(),
    UNPLACED_APP_TRANSLATOR_REL.as_posix(),
    WORKSPACE_TRANSLATOR_REL.as_posix(),
}

FALLBACK_NULL_ANCHOR = "        if (interactor == null) {"
FALLBACK_NULL_REPLACEMENT = (
    "        if (interactor == null || callbacks == null) {"
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

BP_KOTLIN_FLAGS_ANCHOR = '''    kotlincflags: [
        "-Xjvm-default=all",
    ],
'''
BP_KOTLIN_FLAGS_REPLACEMENT = '''    kotlincflags: [
        "-Xjvm-default=all",
        "-Xannotation-default-target=param-property",
    ],
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
    module = replace_once(
        module,
        BP_KOTLIN_FLAGS_ANCHOR,
        BP_KOTLIN_FLAGS_REPLACEMENT,
        "Launcher3QuickStepLib Kotlin annotation targets",
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


def patch_fallback_activity(text: str) -> str:
    return replace_once(
        text,
        FALLBACK_NULL_ANCHOR,
        FALLBACK_NULL_REPLACEMENT,
        "Fallback Quickstep null-callback guard",
    )


def patch_user_cache(text: str) -> str:
    return replace_once(
        text,
        "val user = intent.getParcelableExtra<UserHandle>(Intent.EXTRA_USER) ?: return",
        "val user = intent.getParcelableExtra(Intent.EXTRA_USER, UserHandle::class.java) ?: return",
        "UserCache typed parcelable extra",
    )


def patch_retrying_executor(text: str) -> str:
    text = replace_once(
        text,
        "import android.os.Handler\n",
        "import android.os.Handler\nimport android.os.Looper\n",
        "RetryingExecutor explicit Looper import",
    )
    return replace_once(
        text,
        "class RetryingExecutor(private val handler: Handler = Handler()) {",
        "class RetryingExecutor(private val handler: Handler = Handler(Looper.myLooper() ?: error(\"RetryingExecutor requires a Looper thread\"))) {",
        "RetryingExecutor explicit Looper",
    )


def patch_widget_size_handler(text: str) -> str:
    return replace_once(
        text,
        "fun Bundle.getWidgetSizeList() = getParcelableArrayList<SizeF>(OPTION_APPWIDGET_SIZES)",
        "fun Bundle.getWidgetSizeList() = getParcelableArrayList(OPTION_APPWIDGET_SIZES, SizeF::class.java)",
        "WidgetSizeHandler typed parcelable list",
    )


def patch_preview_context(text: str) -> str:
    text = replace_once(
        text,
        "import java.util.Arrays\n",
        "",
        "PreviewContext obsolete Arrays import",
    )
    return replace_once(
        text,
        "            Arrays.stream(mDbDir.listFiles()).forEach { obj: File -> obj.delete() }",
        "            mDbDir.listFiles()?.forEach { file -> file.delete() }",
        "PreviewContext nullable listFiles",
    )

def patch_wallpaper_theme_manager(text: str) -> str:
    return replace_once(
        text,
        "    override fun onLowMemory() {}",
        "    @Deprecated(\\\"Deprecated framework callback\\\")\\n    override fun onLowMemory() {}",
        "WallpaperThemeManager deprecated override",
    )


def patch_double_shadow_icon_drawable(text: str) -> str:
    return replace_once(
        text,
        "    override fun getOpacity() = PixelFormat.TRANSPARENT",
        "    @Deprecated(\\\"Deprecated Drawable API\\\")\\n    override fun getOpacity() = PixelFormat.TRANSPARENT",
        "DoubleShadowIconDrawable deprecated override",
    )


def patch_item_info_translators(text: str) -> str:
    replacements = (
        ("override fun toSpec(obj: ItemContext<WorkspaceItemInfo>): WorkspaceItemSpec {", "override fun toSpec(info: ItemContext<WorkspaceItemInfo>): WorkspaceItemSpec {"),
        ("override fun toSpec(obj: ItemContext<WorkspaceItemInfo>): HotseatItemSpec {", "override fun toSpec(info: ItemContext<WorkspaceItemInfo>): HotseatItemSpec {"),
        ("override fun toSpec(obj: WorkspaceItemInfo): AppInFolderSpec {", "override fun toSpec(info: WorkspaceItemInfo): AppInFolderSpec {"),
        ("override fun toSpec(obj: ItemContext<LauncherAppWidgetInfo>): WorkspaceItemSpec {", "override fun toSpec(info: ItemContext<LauncherAppWidgetInfo>): WorkspaceItemSpec {"),
        ("override fun toSpec(obj: ItemContext<FolderInfo>): WorkspaceItemSpec {", "override fun toSpec(info: ItemContext<FolderInfo>): WorkspaceItemSpec {"),
        ("override fun toSpec(obj: ItemContext<FolderInfo>): HotseatItemSpec {", "override fun toSpec(info: ItemContext<FolderInfo>): HotseatItemSpec {"),
    )
    for index, (old, new) in enumerate(replacements):
        text = replace_once(text, old, new, f"ItemInfoTranslators signature {index}")
    text = text.replace("obj.item", "info.item")
    text = text.replace("obj.folderContentsMap", "info.folderContentsMap")
    text = text.replace("obj.intent", "info.intent")
    text = text.replace("obj.title", "info.title")
    return text


def patch_unplaced_app_translator(text: str) -> str:
    text = replace_once(
        text,
        "override fun toSpec(app: LauncherActivityInfo): UnplacedAppSpec {",
        "override fun toSpec(info: LauncherActivityInfo): UnplacedAppSpec {",
        "LauncherUnplacedAppTranslator signature",
    )
    return text.replace("app.componentName", "info.componentName").replace("app.label", "info.label").replace("app.getApplicationInfo()", "info.getApplicationInfo()")


def patch_workspace_translator(text: str) -> str:
    text = replace_once(
        text,
        "override fun toSpec(workspace: WorkspaceData): WorkspaceSpec {",
        "override fun toSpec(info: WorkspaceData): WorkspaceSpec {",
        "LauncherWorkspaceTypeTranslator signature",
    )
    return replace_once(
        text,
        "        val filteredItems = workspace.filter {",
        "        val filteredItems = info.filter {",
        "LauncherWorkspaceTypeTranslator usage",
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


def launcher_dirty_paths(launcher: pathlib.Path) -> set[str]:
    proc = subprocess.run(
        [
            "git",
            "-C",
            str(launcher),
            "status",
            "--porcelain=v1",
            "--untracked-files=all",
        ],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        raise FoundationError(
            f"cannot inspect Launcher3 worktree: {proc.stderr.strip()}"
        )

    paths: set[str] = set()
    for raw in proc.stdout.splitlines():
        if len(raw) < 4:
            continue
        path = raw[3:]
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        paths.add(path)
    return paths


def worktree_blob(launcher: pathlib.Path, rel: pathlib.Path) -> str:
    proc = subprocess.run(
        ["git", "-C", str(launcher), "hash-object", rel.as_posix()],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        raise FoundationError(
            f"cannot hash Launcher3 path {rel}: {proc.stderr.strip()}"
        )
    return proc.stdout.strip()


def restore_head_file(launcher: pathlib.Path, rel: pathlib.Path) -> None:
    proc = subprocess.run(
        ["git", "-C", str(launcher), "show", f"HEAD:{rel.as_posix()}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        raise FoundationError(
            f"cannot read pinned Launcher3 path {rel}: "
            + proc.stderr.decode(errors="replace").strip()
        )
    (launcher / rel).write_bytes(proc.stdout)


def normalize_known_legacy_residue(launcher: pathlib.Path) -> None:
    dirty = launcher_dirty_paths(launcher)
    test_path = LEGACY_FALLBACK_TEST_REL.as_posix()
    fallback_path = FALLBACK_ACTIVITY_REL.as_posix()

    if test_path not in dirty:
        return

    if fallback_path not in dirty:
        raise FoundationError(
            "known fallback test residue exists without its production patch"
        )

    fallback_blob = worktree_blob(launcher, FALLBACK_ACTIVITY_REL)
    test_blob = worktree_blob(launcher, LEGACY_FALLBACK_TEST_REL)

    if fallback_blob != KNOWN_LEGACY_FALLBACK_BLOB:
        raise FoundationError(
            "fallback compatibility residue blob mismatch "
            f"expected={KNOWN_LEGACY_FALLBACK_BLOB} actual={fallback_blob}"
        )
    if test_blob != KNOWN_LEGACY_FALLBACK_TEST_BLOB:
        raise FoundationError(
            "fallback regression-test residue blob mismatch "
            f"expected={KNOWN_LEGACY_FALLBACK_TEST_BLOB} actual={test_blob}"
        )

    restore_head_file(launcher, LEGACY_FALLBACK_TEST_REL)

    if LEGACY_FALLBACK_TEST_REL.as_posix() in launcher_dirty_paths(launcher):
        raise FoundationError(
            "failed to normalize malformed fallback regression-test residue"
        )

    print("R9_LAUNCHER3_LEGACY_FALLBACK_TEST=NORMALIZED_TO_PINNED_HEAD")


def validate_preexisting_fallback_compat(launcher: pathlib.Path) -> None:
    fallback_path = FALLBACK_ACTIVITY_REL.as_posix()
    if fallback_path not in launcher_dirty_paths(launcher):
        return

    actual = worktree_blob(launcher, FALLBACK_ACTIVITY_REL)
    if actual != KNOWN_LEGACY_FALLBACK_BLOB:
        raise FoundationError(
            "unrecognized preexisting fallback compatibility blob "
            f"expected={KNOWN_LEGACY_FALLBACK_BLOB} actual={actual}"
        )


def require_recognized_launcher_dirt(
    launcher: pathlib.Path,
    *,
    require_complete: bool,
) -> None:
    dirty = launcher_dirty_paths(launcher)
    unknown = dirty - FOUNDATION_DIRTY_PATHS
    if unknown:
        raise FoundationError(
            "unrecognized Launcher3 dirty paths: "
            + ", ".join(sorted(unknown))
        )
    if require_complete and dirty != FOUNDATION_DIRTY_PATHS:
        missing = FOUNDATION_DIRTY_PATHS - dirty
        extra = dirty - FOUNDATION_DIRTY_PATHS
        raise FoundationError(
            "Launcher3 foundation dirty-set mismatch "
            f"missing={sorted(missing)!r} extra={sorted(extra)!r}"
        )


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
    # R9L7 phase 1 intentionally permits the standalone SableStart module to
    # coexist in source while Launcher3QuickStep compilation is proven. The
    # product cutover/retirement gate is a separate phase and full-image builds
    # remain unauthorized until that retirement is complete.
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

    require_recognized_launcher_dirt(launcher, require_complete=True)
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

    fallback = (launcher / FALLBACK_ACTIVITY_REL).read_text(encoding="utf-8")
    if FALLBACK_NULL_REPLACEMENT not in fallback:
        raise FoundationError(
            "Fallback Quickstep null-callback compatibility guard missing"
        )
    if FALLBACK_NULL_ANCHOR in fallback:
        raise FoundationError(
            "Fallback Quickstep unguarded taskbar bridge remains"
        )

    if '"-Xannotation-default-target=param-property",' not in module:
        raise FoundationError(
            "Launcher3QuickStepLib annotation-target compiler flag missing"
        )

    cleanup_expectations = {
        USER_CACHE_REL: (
            "getParcelableExtra(Intent.EXTRA_USER, UserHandle::class.java)",
        ),
        RETRYING_EXECUTOR_REL: (
            "import android.os.Looper",
            "Handler(Looper.myLooper() ?: error(",
        ),
        WIDGET_SIZE_HANDLER_REL: (
            "getParcelableArrayList(OPTION_APPWIDGET_SIZES, SizeF::class.java)",
        ),
        PREVIEW_CONTEXT_REL: (
            "mDbDir.listFiles()?.forEach",
        ),
    }
    for rel, tokens in cleanup_expectations.items():
        source_text = (launcher / rel).read_text(encoding="utf-8")
        for token in tokens:
            if token not in source_text:
                raise FoundationError(
                    f"Launcher warning-cleanup token missing {rel}: {token}"
                )


def apply_tree(source: pathlib.Path) -> None:
    launcher = source / "packages/apps/Launcher3"
    if git_head(launcher) != LAUNCHER3_HEAD:
        raise FoundationError(
            "refusing Launcher3 mutation because the pinned base HEAD differs"
        )

    normalize_known_legacy_residue(launcher)
    validate_preexisting_fallback_compat(launcher)
    require_recognized_launcher_dirt(launcher, require_complete=False)
    require_workspace_sources(source)

    bp_path = launcher / "Android.bp"
    manifest_path = launcher / "quickstep/AndroidManifest-launcher.xml"
    strings_path = launcher / "quickstep/res/values/strings.xml"
    host_path = launcher / HOST_REL
    fallback_path = launcher / FALLBACK_ACTIVITY_REL
    user_cache_path = launcher / USER_CACHE_REL
    retrying_executor_path = launcher / RETRYING_EXECUTOR_REL
    widget_size_handler_path = launcher / WIDGET_SIZE_HANDLER_REL
    preview_context_path = launcher / PREVIEW_CONTEXT_REL

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
    fallback_path.write_text(
        patch_fallback_activity(fallback_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    user_cache_path.write_text(
        patch_user_cache(user_cache_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    retrying_executor_path.write_text(
        patch_retrying_executor(retrying_executor_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    widget_size_handler_path.write_text(
        patch_widget_size_handler(widget_size_handler_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    preview_context_path.write_text(
        patch_preview_context(preview_context_path.read_text(encoding="utf-8")),
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
    assert '"-Xannotation-default-target=param-property",' in patched_bp

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

    fallback = """before
        if (interactor == null) {
            return superAnimator;
        }
after
"""
    patched_fallback = patch_fallback_activity(fallback)
    assert patch_fallback_activity(patched_fallback) == patched_fallback
    assert FALLBACK_NULL_REPLACEMENT in patched_fallback
    assert FALLBACK_NULL_ANCHOR not in patched_fallback

    user_cache = (
        "val user = intent.getParcelableExtra<UserHandle>(Intent.EXTRA_USER) ?: return"
    )
    assert "UserHandle::class.java" in patch_user_cache(user_cache)

    retrying = (
        "import android.os.Handler\n"
        "class RetryingExecutor(private val handler: Handler = Handler()) {"
    )
    patched_retrying = patch_retrying_executor(retrying)
    assert "import android.os.Looper" in patched_retrying
    assert "Looper.myLooper()" in patched_retrying

    widget_sizes = (
        "fun Bundle.getWidgetSizeList() = "
        "getParcelableArrayList<SizeF>(OPTION_APPWIDGET_SIZES)"
    )
    assert "SizeF::class.java" in patch_widget_size_handler(widget_sizes)

    preview = (
        "import java.util.Arrays\n"
        "            Arrays.stream(mDbDir.listFiles()).forEach { obj: File -> obj.delete() }"
    )
    patched_preview = patch_preview_context(preview)
    assert "listFiles()?.forEach" in patched_preview
    assert "java.util.Arrays" not in patched_preview

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
            print("R9_LAUNCHER3_PHASE=HOST_COMPILE_BEFORE_STANDALONE_RETIREMENT")
        else:
            verify_tree(source)
            print("R9_LAUNCHER3_DIRTY_PATHS=PASS")
            print("R9_LAUNCHER3_FALLBACK_NULL_CALLBACK_COMPAT=PASS")
            print("R9_LAUNCHER3_WARNING_CLEANUP_SAFE_MIGRATIONS=PASS")
            print("R9_LAUNCHER3_FOUNDATION_VERIFY=PASS")
    except FoundationError as exc:
        print(f"R9_LAUNCHER3_FOUNDATION=FAIL {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
