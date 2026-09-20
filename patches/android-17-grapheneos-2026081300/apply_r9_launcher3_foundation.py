#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re
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
PREVIEW_LIFECYCLE_REL = pathlib.Path(
    "src/com/android/launcher3/preview/PreviewLifecycleObserver.kt"
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

UTILITIES_KT_REL = pathlib.Path("src/com/android/launcher3/UtilitiesKt.kt")
CACHEABLE_SHORTCUT_REL = pathlib.Path(
    "src/com/android/launcher3/icons/CacheableShortcutInfo.kt"
)
DISPLAY_INFO_CONTAINER_REL = pathlib.Path(
    "src/com/android/launcher3/display/DisplayInfoContainer.kt"
)
MODEL_WRITER_REL = pathlib.Path("src/com/android/launcher3/model/ModelWriter.kt")
FAKE_MODEL_WRITER_REL = pathlib.Path(
    "src/com/android/launcher3/model/testing/FakeModelWriter.kt"
)
DESKTOP_VISIBILITY_REL = pathlib.Path(
    "quickstep/src/com/android/launcher3/statehandlers/DesktopVisibilityController.kt"
)
OVERFLOWN_APPS_REL = pathlib.Path(
    "quickstep/src/com/android/launcher3/taskbar/OverflownAppsContainerView.kt"
)
BUBBLE_BAR_BACKGROUND_REL = pathlib.Path(
    "quickstep/src/com/android/launcher3/taskbar/bubbles/BubbleBarBackground.kt"
)
PHONE_LANDSCAPE_NAV_REL = pathlib.Path(
    "quickstep/src/com/android/launcher3/taskbar/navbutton/PhoneLandscapeNavLayoutter.kt"
)
STATS_LOG_COMPAT_REL = pathlib.Path(
    "quickstep/src/com/android/quickstep/logging/StatsLogCompatManager.kt"
)
SEASCAPE_HANDLER_REL = pathlib.Path(
    "quickstep/src/com/android/quickstep/orientation/SeascapePagedViewHandler.kt"
)
GROUP_TASK_REL = pathlib.Path("quickstep/src/com/android/quickstep/util/GroupTask.kt")
DESKTOP_TASK_VIEW_REL = pathlib.Path(
    "quickstep/src/com/android/quickstep/views/DesktopTaskView.kt"
)
FLOATING_APP_PAIR_BACKGROUND_REL = pathlib.Path(
    "quickstep/src/com/android/quickstep/views/FloatingAppPairBackground.kt"
)
PRELOAD_ICON_DELEGATE_REL = pathlib.Path(
    "src/com/android/launcher3/graphics/PreloadIconDelegate.kt"
)
DB_ENTRY_REL = pathlib.Path("src/com/android/launcher3/model/DbEntry.kt")
ADD_ITEM_ACTIVITY_REL = pathlib.Path(
    "src/com/android/launcher3/dragndrop/AddItemActivity.kt"
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
    PREVIEW_LIFECYCLE_REL.as_posix(),
    WALLPAPER_THEME_MANAGER_REL.as_posix(),
    DOUBLE_SHADOW_ICON_DRAWABLE_REL.as_posix(),
    ITEM_INFO_TRANSLATORS_REL.as_posix(),
    UNPLACED_APP_TRANSLATOR_REL.as_posix(),
    WORKSPACE_TRANSLATOR_REL.as_posix(),
    UTILITIES_KT_REL.as_posix(),
    CACHEABLE_SHORTCUT_REL.as_posix(),
    DISPLAY_INFO_CONTAINER_REL.as_posix(),
    MODEL_WRITER_REL.as_posix(),
    FAKE_MODEL_WRITER_REL.as_posix(),
    DESKTOP_VISIBILITY_REL.as_posix(),
    OVERFLOWN_APPS_REL.as_posix(),
    BUBBLE_BAR_BACKGROUND_REL.as_posix(),
    PHONE_LANDSCAPE_NAV_REL.as_posix(),
    STATS_LOG_COMPAT_REL.as_posix(),
    SEASCAPE_HANDLER_REL.as_posix(),
    GROUP_TASK_REL.as_posix(),
    DESKTOP_TASK_VIEW_REL.as_posix(),
    FLOATING_APP_PAIR_BACKGROUND_REL.as_posix(),
    PRELOAD_ICON_DELEGATE_REL.as_posix(),
    DB_ENTRY_REL.as_posix(),
    ADD_ITEM_ACTIVITY_REL.as_posix(),
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


def replace_exact_count(
    text: str,
    old: str,
    new: str,
    expected: int,
    label: str,
) -> str:
    old_count = text.count(old)
    new_count = text.count(new)
    if old_count == 0 and new_count == expected:
        return text
    if old_count != expected:
        raise FoundationError(
            f"{label}: expected {expected} anchors, found {old_count}"
        )
    return text.replace(old, new)


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
    obsolete_import = "import java.util.Arrays\n"
    if obsolete_import in text:
        if text.count(obsolete_import) != 1:
            raise FoundationError(
                "PreviewContext obsolete Arrays import: expected exactly one anchor"
            )
        text = text.replace(obsolete_import, "", 1)

    return replace_once(
        text,
        "            Arrays.stream(mDbDir.listFiles()).forEach { obj: File -> obj.delete() }",
        "            mDbDir.listFiles()?.forEach { file -> file.delete() }",
        "PreviewContext nullable listFiles",
    )

def patch_preview_lifecycle(text: str) -> str:
    replacements = (
        ("MESSAGE_ID_UPDATE_SHAPE", "LEGACY_MESSAGE_ID_UPDATE_SHAPE"),
        ("MESSAGE_ID_UPDATE_GRID", "LEGACY_MESSAGE_ID_UPDATE_GRID"),
        ("MESSAGE_ID_UPDATE_ICON_THEMED", "LEGACY_MESSAGE_ID_UPDATE_ICON_THEMED"),
    )
    for old, new in replacements:
        text = re.sub(rf"(?<![A-Za-z0-9_]){re.escape(old)}(?![A-Za-z0-9_])", new, text)

    annotation = '        @Deprecated("Use [MESSAGE_ID_UPDATE_COMMAND] instead")\n'
    text = text.replace(annotation, "")
    return text


def patch_wallpaper_theme_manager(text: str) -> str:
    return replace_once(
        text,
        "    override fun onLowMemory() {}",
        "    @Deprecated(\"Deprecated framework callback\")\n    override fun onLowMemory() {}",
        "WallpaperThemeManager deprecated override",
    )


def patch_double_shadow_icon_drawable(text: str) -> str:
    return replace_once(
        text,
        "    override fun getOpacity() = PixelFormat.TRANSPARENT",
        "    @Deprecated(\"Deprecated Drawable API\")\n    override fun getOpacity() = PixelFormat.TRANSPARENT",
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


def patch_utilities_kt(text: str) -> str:
    text = replace_once(
        text,
        "            override fun setAttribute(viewGroup: ViewGroup, clipChildren: Boolean) {\n"
        "                viewGroup.clipChildren = clipChildren\n"
        "            }",
        "            override fun setAttribute(viewGroup: ViewGroup, attr: Boolean) {\n"
        "                viewGroup.clipChildren = attr\n"
        "            }",
        "UtilitiesKt clipChildren override parameter",
    )
    return replace_once(
        text,
        "            override fun setAttribute(viewGroup: ViewGroup, clipToPadding: Boolean) {\n"
        "                viewGroup.clipToPadding = clipToPadding\n"
        "            }",
        "            override fun setAttribute(viewGroup: ViewGroup, attr: Boolean) {\n"
        "                viewGroup.clipToPadding = attr\n"
        "            }",
        "UtilitiesKt clipToPadding override parameter",
    )


def patch_cacheable_shortcut(text: str) -> str:
    text = replace_once(
        text,
        "    override fun getFreshnessIdentifier(item: CacheableShortcutInfo, provider: IconProvider) =",
        "    override fun getFreshnessIdentifier(item: CacheableShortcutInfo, iconProvider: IconProvider) =",
        "CacheableShortcutInfo override parameter",
    )
    return replace_once(
        text,
        "        provider\n            .getStateForApp",
        "        iconProvider\n            .getStateForApp",
        "CacheableShortcutInfo provider usage",
    )


def mark_deprecated_override(text: str, signature: str, message: str, label: str) -> str:
    indent = signature[: len(signature) - len(signature.lstrip())]
    replacement = f'{indent}@Deprecated("{message}")\n{signature}'
    return replace_once(text, signature, replacement, label)


def patch_display_info_container(text: str) -> str:
    return mark_deprecated_override(
        text,
        "    override fun onLowMemory() {}",
        "Deprecated ComponentCallbacks callback",
        "DisplayInfoContainer deprecated override",
    )


def patch_model_writer(text: str) -> str:
    return mark_deprecated_override(
        text,
        "    override fun getNotifier(): LauncherUiStateNotifier = launcherStateNotifier",
        "Temporary interface for ui notification",
        "ModelWriter deprecated override",
    )


def patch_fake_model_writer(text: str) -> str:
    return mark_deprecated_override(
        text,
        "    override fun getNotifier(): LauncherUiStateNotifier = notifier",
        "Temporary interface for ui notification",
        "FakeModelWriter deprecated override",
    )


def patch_desktop_visibility(text: str) -> str:
    return mark_deprecated_override(
        text,
        "        override fun onStashedChanged(displayId: Int, stashed: Boolean) {}",
        "Deprecated desktop task listener callback",
        "DesktopVisibilityController deprecated override",
    )


def patch_overflown_apps(text: str) -> str:
    return replace_once(
        text,
        "    override fun reserveDropSlotForDragLocation(x: Int) {\n"
        "        dragDelegate.reserveDropSlotForDragLocation(x)\n"
        "    }",
        "    override fun reserveDropSlotForDragLocation(onScreenLocationX: Int) {\n"
        "        dragDelegate.reserveDropSlotForDragLocation(onScreenLocationX)\n"
        "    }",
        "OverflownAppsContainerView override parameter",
    )


def patch_bubble_bar_background(text: str) -> str:
    return mark_deprecated_override(
        text,
        "    override fun getOpacity(): Int {",
        "Deprecated Drawable API",
        "BubbleBarBackground deprecated override",
    )


def patch_phone_landscape_nav(text: str) -> str:
    text = replace_once(
        text,
        "        barAxisMarginTop: Int,\n        barAxisMarginBottom: Int,",
        "        barAxisMarginStart: Int,\n        barAxisMarginEnd: Int,",
        "PhoneLandscapeNavLayoutter override parameters",
    )
    text = replace_once(
        text,
        "            topMargin = barAxisMarginTop\n            bottomMargin = barAxisMarginBottom",
        "            topMargin = barAxisMarginStart\n            bottomMargin = barAxisMarginEnd",
        "PhoneLandscapeNavLayoutter parameter usage",
    )
    return text


def patch_stats_log_compat(text: str) -> str:
    return replace_once(
        text,
        "        override fun withEndTimestamp(endTimeInMillis: Long) = apply {\n"
        "            this.mEndTimeInMillis = endTimeInMillis\n"
        "        }",
        "        override fun withEndTimestamp(timestampInMillis: Long) = apply {\n"
        "            this.mEndTimeInMillis = timestampInMillis\n"
        "        }",
        "StatsLogCompatManager override parameter",
    )


def patch_seascape_handler(text: str) -> str:
    text = replace_once(
        text,
        "        appChipView: IconAppChipView,",
        "        iconView: IconAppChipView,",
        "SeascapePagedViewHandler override parameter",
    )
    replacements = (
        (
            "        val layoutParams = appChipView.layoutParams as FrameLayout.LayoutParams",
            "        val layoutParams = iconView.layoutParams as FrameLayout.LayoutParams",
        ),
        (
            "        appChipView.layoutParams = layoutParams",
            "        iconView.layoutParams = layoutParams",
        ),
        (
            "        appChipView.setSplitTranslationX(0f)",
            "        iconView.setSplitTranslationX(0f)",
        ),
        (
            "        appChipView.setSplitTranslationY(translationY.toFloat())",
            "        iconView.setSplitTranslationY(translationY.toFloat())",
        ),
    )
    for old, new in replacements:
        text = replace_once(text, old, new, "SeascapePagedViewHandler parameter usage")
    return text


def patch_group_task(text: str) -> str:
    text = replace_exact_count(
        text,
        "override fun equals(o: Any?): Boolean {",
        "override fun equals(other: Any?): Boolean {",
        3,
        "GroupTask equals override parameter",
    )
    text = replace_exact_count(
        text,
        "if (this === o) return true",
        "if (this === other) return true",
        3,
        "GroupTask identity check",
    )
    for old, new, label in (
        ("if (o !is GroupTask) return false", "if (other !is GroupTask) return false", "GroupTask type check"),
        ("if (o !is SingleTask) return false", "if (other !is SingleTask) return false", "SingleTask type check"),
        ("if (o !is SplitTask) return false", "if (other !is SplitTask) return false", "SplitTask type check"),
        ("o.taskViewType", "other.taskViewType", "GroupTask taskViewType usage"),
        ("o.tasks", "other.tasks", "GroupTask tasks usage"),
        ("o.splitBounds", "other.splitBounds", "SplitTask bounds usage"),
    ):
        text = replace_exact_count(text, old, new, 1, label)
    text = replace_exact_count(
        text,
        "super.equals(o)",
        "super.equals(other)",
        2,
        "GroupTask superclass equality",
    )
    return text


def patch_desktop_task_view(text: str) -> str:
    return replace_once(
        text,
        "    override fun onConfigurationChanged(newConfig: Configuration?) {\n"
        "        super.onConfigurationChanged(newConfig)",
        "    override fun onConfigurationChanged(p0: Configuration?) {\n"
        "        super.onConfigurationChanged(p0)",
        "DesktopTaskView override parameter",
    )


def patch_floating_app_pair_background(text: str) -> str:
    return mark_deprecated_override(
        text,
        "    override fun getOpacity(): Int {",
        "Deprecated Drawable API",
        "FloatingAppPairBackground deprecated override",
    )


def patch_preload_icon_delegate(text: str) -> str:
    for resource in (
        "materialColorInverseSurface",
        "materialColorPrimary",
        "materialColorSecondary",
    ):
        text = replace_once(
            text,
            f"context.resources.getColor(R.color.{resource})",
            f"context.getColor(R.color.{resource})",
            f"PreloadIconDelegate {resource} color API",
        )
    return text


def patch_db_entry(text: str) -> str:
    return replace_once(
        text,
        "Intent.parseUri(intentStr, 0).apply { sourceBounds = null }.toURI()",
        "Intent.parseUri(intentStr, 0).apply { sourceBounds = null }.toUri(0)",
        "DbEntry Intent URI API",
    )


def patch_add_item_activity(text: str) -> str:
    return replace_once(
        text,
        "sendWidgetAddedToScreenAccessibilityEvent(widgetProviderInfo.label)",
        "sendWidgetAddedToScreenAccessibilityEvent(widgetProviderInfo.loadLabel(packageManager))",
        "AddItemActivity widget label API",
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
        PREVIEW_LIFECYCLE_REL: (
            "LEGACY_MESSAGE_ID_UPDATE_SHAPE",
            "LEGACY_MESSAGE_ID_UPDATE_GRID",
            "LEGACY_MESSAGE_ID_UPDATE_ICON_THEMED",
        ),
        WALLPAPER_THEME_MANAGER_REL: (
            '@Deprecated("Deprecated framework callback")',
        ),
        DOUBLE_SHADOW_ICON_DRAWABLE_REL: (
            '@Deprecated("Deprecated Drawable API")',
        ),
        ITEM_INFO_TRANSLATORS_REL: (
            "toSpec(info: ItemContext<WorkspaceItemInfo>)",
            "toSpec(info: WorkspaceItemInfo)",
            "toSpec(info: ItemContext<LauncherAppWidgetInfo>)",
            "toSpec(info: ItemContext<FolderInfo>)",
        ),
        UNPLACED_APP_TRANSLATOR_REL: (
            "toSpec(info: LauncherActivityInfo)",
        ),
        WORKSPACE_TRANSLATOR_REL: (
            "toSpec(info: WorkspaceData)",
            "val filteredItems = info.filter",
        ),
        UTILITIES_KT_REL: (
            "override fun setAttribute(viewGroup: ViewGroup, attr: Boolean)",
            "viewGroup.clipChildren = attr",
            "viewGroup.clipToPadding = attr",
        ),
        CACHEABLE_SHORTCUT_REL: (
            "getFreshnessIdentifier(item: CacheableShortcutInfo, iconProvider: IconProvider)",
            "iconProvider\n            .getStateForApp",
        ),
        DISPLAY_INFO_CONTAINER_REL: (
            '@Deprecated("Deprecated ComponentCallbacks callback")',
        ),
        MODEL_WRITER_REL: (
            '@Deprecated("Temporary interface for ui notification")',
        ),
        FAKE_MODEL_WRITER_REL: (
            '@Deprecated("Temporary interface for ui notification")',
        ),
        DESKTOP_VISIBILITY_REL: (
            '@Deprecated("Deprecated desktop task listener callback")',
        ),
        OVERFLOWN_APPS_REL: (
            "reserveDropSlotForDragLocation(onScreenLocationX: Int)",
        ),
        BUBBLE_BAR_BACKGROUND_REL: (
            '@Deprecated("Deprecated Drawable API")',
        ),
        PHONE_LANDSCAPE_NAV_REL: (
            "barAxisMarginStart: Int",
            "barAxisMarginEnd: Int",
        ),
        STATS_LOG_COMPAT_REL: (
            "withEndTimestamp(timestampInMillis: Long)",
        ),
        SEASCAPE_HANDLER_REL: (
            "iconView: IconAppChipView",
            "iconView.setSplitTranslationX",
            "iconView.setSplitTranslationY",
        ),
        GROUP_TASK_REL: (
            "override fun equals(other: Any?): Boolean",
        ),
        DESKTOP_TASK_VIEW_REL: (
            "override fun onConfigurationChanged(p0: Configuration?)",
        ),
        FLOATING_APP_PAIR_BACKGROUND_REL: (
            '@Deprecated("Deprecated Drawable API")',
        ),
        PRELOAD_ICON_DELEGATE_REL: (
            "context.getColor(R.color.materialColorInverseSurface)",
            "context.getColor(R.color.materialColorPrimary)",
            "context.getColor(R.color.materialColorSecondary)",
        ),
        DB_ENTRY_REL: (
            "Intent.parseUri(intentStr, 0).apply { sourceBounds = null }.toUri(0)",
        ),
        ADD_ITEM_ACTIVITY_REL: (
            "widgetProviderInfo.loadLabel(packageManager)",
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
    preview_lifecycle_path = launcher / PREVIEW_LIFECYCLE_REL
    wallpaper_theme_manager_path = launcher / WALLPAPER_THEME_MANAGER_REL
    double_shadow_icon_drawable_path = launcher / DOUBLE_SHADOW_ICON_DRAWABLE_REL
    item_info_translators_path = launcher / ITEM_INFO_TRANSLATORS_REL
    unplaced_app_translator_path = launcher / UNPLACED_APP_TRANSLATOR_REL
    workspace_translator_path = launcher / WORKSPACE_TRANSLATOR_REL
    utilities_kt_path = launcher / UTILITIES_KT_REL
    cacheable_shortcut_path = launcher / CACHEABLE_SHORTCUT_REL
    display_info_container_path = launcher / DISPLAY_INFO_CONTAINER_REL
    model_writer_path = launcher / MODEL_WRITER_REL
    fake_model_writer_path = launcher / FAKE_MODEL_WRITER_REL
    desktop_visibility_path = launcher / DESKTOP_VISIBILITY_REL
    overflown_apps_path = launcher / OVERFLOWN_APPS_REL
    bubble_bar_background_path = launcher / BUBBLE_BAR_BACKGROUND_REL
    phone_landscape_nav_path = launcher / PHONE_LANDSCAPE_NAV_REL
    stats_log_compat_path = launcher / STATS_LOG_COMPAT_REL
    seascape_handler_path = launcher / SEASCAPE_HANDLER_REL
    group_task_path = launcher / GROUP_TASK_REL
    desktop_task_view_path = launcher / DESKTOP_TASK_VIEW_REL
    floating_app_pair_background_path = launcher / FLOATING_APP_PAIR_BACKGROUND_REL
    preload_icon_delegate_path = launcher / PRELOAD_ICON_DELEGATE_REL
    db_entry_path = launcher / DB_ENTRY_REL
    add_item_activity_path = launcher / ADD_ITEM_ACTIVITY_REL

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
    preview_lifecycle_path.write_text(
        patch_preview_lifecycle(preview_lifecycle_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    wallpaper_theme_manager_path.write_text(
        patch_wallpaper_theme_manager(
            wallpaper_theme_manager_path.read_text(encoding="utf-8")
        ),
        encoding="utf-8",
    )
    double_shadow_icon_drawable_path.write_text(
        patch_double_shadow_icon_drawable(
            double_shadow_icon_drawable_path.read_text(encoding="utf-8")
        ),
        encoding="utf-8",
    )
    item_info_translators_path.write_text(
        patch_item_info_translators(
            item_info_translators_path.read_text(encoding="utf-8")
        ),
        encoding="utf-8",
    )
    unplaced_app_translator_path.write_text(
        patch_unplaced_app_translator(
            unplaced_app_translator_path.read_text(encoding="utf-8")
        ),
        encoding="utf-8",
    )
    workspace_translator_path.write_text(
        patch_workspace_translator(
            workspace_translator_path.read_text(encoding="utf-8")
        ),
        encoding="utf-8",
    )
    utilities_kt_path.write_text(
        patch_utilities_kt(utilities_kt_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    cacheable_shortcut_path.write_text(
        patch_cacheable_shortcut(cacheable_shortcut_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    display_info_container_path.write_text(
        patch_display_info_container(
            display_info_container_path.read_text(encoding="utf-8")
        ),
        encoding="utf-8",
    )
    model_writer_path.write_text(
        patch_model_writer(model_writer_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    fake_model_writer_path.write_text(
        patch_fake_model_writer(fake_model_writer_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    desktop_visibility_path.write_text(
        patch_desktop_visibility(desktop_visibility_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    overflown_apps_path.write_text(
        patch_overflown_apps(overflown_apps_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    bubble_bar_background_path.write_text(
        patch_bubble_bar_background(
            bubble_bar_background_path.read_text(encoding="utf-8")
        ),
        encoding="utf-8",
    )
    phone_landscape_nav_path.write_text(
        patch_phone_landscape_nav(phone_landscape_nav_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    stats_log_compat_path.write_text(
        patch_stats_log_compat(stats_log_compat_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    seascape_handler_path.write_text(
        patch_seascape_handler(seascape_handler_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    group_task_path.write_text(
        patch_group_task(group_task_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    desktop_task_view_path.write_text(
        patch_desktop_task_view(desktop_task_view_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    floating_app_pair_background_path.write_text(
        patch_floating_app_pair_background(
            floating_app_pair_background_path.read_text(encoding="utf-8")
        ),
        encoding="utf-8",
    )
    preload_icon_delegate_path.write_text(
        patch_preload_icon_delegate(
            preload_icon_delegate_path.read_text(encoding="utf-8")
        ),
        encoding="utf-8",
    )
    db_entry_path.write_text(
        patch_db_entry(db_entry_path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    add_item_activity_path.write_text(
        patch_add_item_activity(add_item_activity_path.read_text(encoding="utf-8")),
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
    kotlincflags: [
        "-Xjvm-default=all",
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

    wallpaper = "    override fun onLowMemory() {}"
    assert '@Deprecated("Deprecated framework callback")' in patch_wallpaper_theme_manager(
        wallpaper
    )

    drawable = "    override fun getOpacity() = PixelFormat.TRANSPARENT"
    assert '@Deprecated("Deprecated Drawable API")' in patch_double_shadow_icon_drawable(
        drawable
    )

    translators = """override fun toSpec(obj: ItemContext<WorkspaceItemInfo>): WorkspaceItemSpec {
        val item = obj.item
override fun toSpec(obj: ItemContext<WorkspaceItemInfo>): HotseatItemSpec {
        val item = obj.item
override fun toSpec(obj: WorkspaceItemInfo): AppInFolderSpec {
        label = obj.title
override fun toSpec(obj: ItemContext<LauncherAppWidgetInfo>): WorkspaceItemSpec {
        val item = obj.item
override fun toSpec(obj: ItemContext<FolderInfo>): WorkspaceItemSpec {
        val item = obj.item
        obj.folderContentsMap
override fun toSpec(obj: ItemContext<FolderInfo>): HotseatItemSpec {
        val item = obj.item
        obj.folderContentsMap
"""
    patched_translators = patch_item_info_translators(translators)
    assert "toSpec(info:" in patched_translators
    assert "obj.item" not in patched_translators
    assert "obj.folderContentsMap" not in patched_translators

    unplaced = """override fun toSpec(app: LauncherActivityInfo): UnplacedAppSpec {
app.componentName
app.label
app.getApplicationInfo()
"""
    patched_unplaced = patch_unplaced_app_translator(unplaced)
    assert "toSpec(info: LauncherActivityInfo)" in patched_unplaced
    assert "app.componentName" not in patched_unplaced

    workspace = """override fun toSpec(workspace: WorkspaceData): WorkspaceSpec {
        val filteredItems = workspace.filter {
"""
    patched_workspace = patch_workspace_translator(workspace)
    assert "toSpec(info: WorkspaceData)" in patched_workspace
    assert "val filteredItems = info.filter" in patched_workspace

    preview_lifecycle = """        @Deprecated("Use [MESSAGE_ID_UPDATE_COMMAND] instead")
        private const val MESSAGE_ID_UPDATE_SHAPE = 2586
        @Deprecated("Use [MESSAGE_ID_UPDATE_COMMAND] instead")
        private const val MESSAGE_ID_UPDATE_GRID = 7414
        @Deprecated("Use [MESSAGE_ID_UPDATE_COMMAND] instead")
        private const val MESSAGE_ID_UPDATE_ICON_THEMED = 311
        MESSAGE_ID_UPDATE_SHAPE
        MESSAGE_ID_UPDATE_GRID
        MESSAGE_ID_UPDATE_ICON_THEMED
"""
    patched_preview_lifecycle = patch_preview_lifecycle(preview_lifecycle)
    assert "LEGACY_MESSAGE_ID_UPDATE_SHAPE" in patched_preview_lifecycle
    assert "LEGACY_MESSAGE_ID_UPDATE_GRID" in patched_preview_lifecycle
    assert "LEGACY_MESSAGE_ID_UPDATE_ICON_THEMED" in patched_preview_lifecycle
    assert "@Deprecated" not in patched_preview_lifecycle
    assert (
        patch_preview_lifecycle(patched_preview_lifecycle)
        == patched_preview_lifecycle
    )
    assert "LEGACY_LEGACY_" not in patched_preview_lifecycle

    utilities = """            override fun setAttribute(viewGroup: ViewGroup, clipChildren: Boolean) {
                viewGroup.clipChildren = clipChildren
            }
            override fun setAttribute(viewGroup: ViewGroup, clipToPadding: Boolean) {
                viewGroup.clipToPadding = clipToPadding
            }
"""
    patched_utilities = patch_utilities_kt(utilities)
    assert "clipChildren = attr" in patched_utilities
    assert "clipToPadding = attr" in patched_utilities
    assert patch_utilities_kt(patched_utilities) == patched_utilities

    cacheable = """    override fun getFreshnessIdentifier(item: CacheableShortcutInfo, provider: IconProvider) =
        provider
            .getStateForApp(item.appInfo)
"""
    patched_cacheable = patch_cacheable_shortcut(cacheable)
    assert "iconProvider: IconProvider" in patched_cacheable
    assert "iconProvider\n            .getStateForApp" in patched_cacheable
    assert patch_cacheable_shortcut(patched_cacheable) == patched_cacheable

    nested_override = "        override fun onStashedChanged(displayId: Int, stashed: Boolean) {}"
    patched_nested_override = patch_desktop_visibility(nested_override)
    assert (
        '        @Deprecated("Deprecated desktop task listener callback")\n'
        in patched_nested_override
    )
    assert patch_desktop_visibility(patched_nested_override) == patched_nested_override

    overflow = """    override fun reserveDropSlotForDragLocation(x: Int) {
        dragDelegate.reserveDropSlotForDragLocation(x)
    }
"""
    patched_overflow = patch_overflown_apps(overflow)
    assert "onScreenLocationX: Int" in patched_overflow
    assert patch_overflown_apps(patched_overflow) == patched_overflow

    phone_nav = """        barAxisMarginTop: Int,
        barAxisMarginBottom: Int,
            topMargin = barAxisMarginTop
            bottomMargin = barAxisMarginBottom
"""
    patched_phone_nav = patch_phone_landscape_nav(phone_nav)
    assert "barAxisMarginStart: Int" in patched_phone_nav
    assert "barAxisMarginEnd: Int" in patched_phone_nav
    assert patch_phone_landscape_nav(patched_phone_nav) == patched_phone_nav

    stats = """        override fun withEndTimestamp(endTimeInMillis: Long) = apply {
            this.mEndTimeInMillis = endTimeInMillis
        }
"""
    patched_stats = patch_stats_log_compat(stats)
    assert "withEndTimestamp(timestampInMillis: Long)" in patched_stats
    assert patch_stats_log_compat(patched_stats) == patched_stats

    seascape = """        appChipView: IconAppChipView,
        val layoutParams = appChipView.layoutParams as FrameLayout.LayoutParams
        appChipView.layoutParams = layoutParams
        appChipView.setSplitTranslationX(0f)
        appChipView.setSplitTranslationY(translationY.toFloat())
"""
    patched_seascape = patch_seascape_handler(seascape)
    assert "iconView: IconAppChipView" in patched_seascape
    assert "appChipView" not in patched_seascape
    assert patch_seascape_handler(patched_seascape) == patched_seascape

    group_task = """    override fun equals(o: Any?): Boolean {
        if (this === o) return true
        if (o !is GroupTask) return false
        return taskViewType == o.taskViewType && tasks == o.tasks
    }
    override fun equals(o: Any?): Boolean {
        if (this === o) return true
        if (o !is SingleTask) return false
        return super.equals(o)
    }
    override fun equals(o: Any?): Boolean {
        if (this === o) return true
        if (o !is SplitTask) return false
        if (splitBounds != o.splitBounds) return false
        return super.equals(o)
    }
"""
    patched_group_task = patch_group_task(group_task)
    assert "equals(other: Any?)" in patched_group_task
    assert "equals(o: Any?)" not in patched_group_task
    assert patch_group_task(patched_group_task) == patched_group_task

    desktop_task = """    override fun onConfigurationChanged(newConfig: Configuration?) {
        super.onConfigurationChanged(newConfig)
"""
    patched_desktop_task = patch_desktop_task_view(desktop_task)
    assert "onConfigurationChanged(p0: Configuration?)" in patched_desktop_task
    assert patch_desktop_task_view(patched_desktop_task) == patched_desktop_task

    preload = (
        "context.resources.getColor(R.color.materialColorInverseSurface)\n"
        "context.resources.getColor(R.color.materialColorPrimary)\n"
        "context.resources.getColor(R.color.materialColorSecondary)"
    )
    patched_preload = patch_preload_icon_delegate(preload)
    assert "context.resources.getColor" not in patched_preload
    assert patch_preload_icon_delegate(patched_preload) == patched_preload

    db_entry = "Intent.parseUri(intentStr, 0).apply { sourceBounds = null }.toURI()"
    patched_db_entry = patch_db_entry(db_entry)
    assert ".toUri(0)" in patched_db_entry
    assert patch_db_entry(patched_db_entry) == patched_db_entry

    add_item = "sendWidgetAddedToScreenAccessibilityEvent(widgetProviderInfo.label)"
    patched_add_item = patch_add_item_activity(add_item)
    assert "widgetProviderInfo.loadLabel(packageManager)" in patched_add_item
    assert patch_add_item_activity(patched_add_item) == patched_add_item

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
