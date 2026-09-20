#!/usr/bin/env python3
from __future__ import annotations

import argparse
import collections
import pathlib
import re
import sys

WARNING_RE = re.compile(r"^(?P<prefix>.*?)(?P<message>warning: .+)$")

SABLE_PATH_MARKERS = (
    "packages/apps/SableDesign/",
    "packages/apps/SableStart/",
    "packages/apps/Launcher3/quickstep/src/com/android/launcher3/sable/",
)

R8_API37_WARNING = "An API level of 37 is not supported by this compiler"

GLOBAL_MIGRATED_WARNING_MARKERS = (
    # The Launcher3QuickStepLib compiler flag is intended to eliminate this
    # warning class for the entire hosted launcher module.
    "this annotation is currently applied to the value parameter only",
)

MIGRATED_WARNING_RULES = (
    ("packages/apps/Launcher3/src/com/android/launcher3/pm/UserCache.kt", "getParcelableExtra(p0: String"),
    ("packages/apps/Launcher3/src/com/android/launcher3/util/RetryingExecutor.kt", "'constructor(): Handler' is deprecated"),
    ("packages/apps/Launcher3/src/com/android/launcher3/widget/util/WidgetSizeHandler.kt", "getParcelableArrayList(p0: String?)"),
    ("packages/apps/Launcher3/src/com/android/launcher3/preview/PreviewContext.kt", "Only safe (?.) or non-null asserted (!!.) calls"),
    ("packages/apps/Launcher3/src/com/android/launcher3/util/WallpaperThemeManager.kt", "overrides a deprecated member but is not marked as deprecated itself"),
    ("packages/apps/Launcher3/src/com/android/launcher3/views/DoubleShadowIconDrawable.kt", "overrides a deprecated member but is not marked as deprecated itself"),
    ("packages/apps/Launcher3/src/com/android/launcher3/preview/PreviewLifecycleObserver.kt", "MESSAGE_ID_UPDATE_SHAPE: Int' is deprecated"),
    ("packages/apps/Launcher3/src/com/android/launcher3/preview/PreviewLifecycleObserver.kt", "MESSAGE_ID_UPDATE_GRID: Int' is deprecated"),
    ("packages/apps/Launcher3/src/com/android/launcher3/preview/PreviewLifecycleObserver.kt", "MESSAGE_ID_UPDATE_ICON_THEMED: Int' is deprecated"),
    ("packages/apps/SableDesign/", "statusBarColor: Int' is deprecated"),
    ("packages/apps/SableDesign/", "navigationBarColor: Int' is deprecated"),
    ("packages/apps/Launcher3/src/com/android/launcher3/UtilitiesKt.kt", "corresponding parameter in the supertype"),
    ("packages/apps/Launcher3/src/com/android/launcher3/icons/CacheableShortcutInfo.kt", "corresponding parameter in the supertype"),
    ("packages/apps/Launcher3/src/com/android/launcher3/display/DisplayInfoContainer.kt", "overrides a deprecated member but is not marked as deprecated itself"),
    ("packages/apps/Launcher3/src/com/android/launcher3/model/ModelWriter.kt", "overrides a deprecated member but is not marked as deprecated itself"),
    ("packages/apps/Launcher3/src/com/android/launcher3/model/ModelWriter.kt", "static field IS_DEBUG_DEVICE: Boolean' is deprecated"),
    ("packages/apps/Launcher3/src/com/android/launcher3/model/ModelWriter.kt", "static field IS_STUDIO_BUILD: Boolean' is deprecated"),
    ("packages/apps/Launcher3/src/com/android/launcher3/model/testing/FakeModelWriter.kt", "overrides a deprecated member but is not marked as deprecated itself"),
    ("packages/apps/Launcher3/quickstep/src/com/android/launcher3/statehandlers/DesktopVisibilityController.kt", "overrides a deprecated member but is not marked as deprecated itself"),
    ("packages/apps/Launcher3/quickstep/src/com/android/launcher3/taskbar/OverflownAppsContainerView.kt", "corresponding parameter in the supertype"),
    ("packages/apps/Launcher3/quickstep/src/com/android/launcher3/taskbar/bubbles/BubbleBarBackground.kt", "overrides a deprecated member but is not marked as deprecated itself"),
    ("packages/apps/Launcher3/quickstep/src/com/android/launcher3/taskbar/navbutton/PhoneLandscapeNavLayoutter.kt", "corresponding parameter in the supertype"),
    ("packages/apps/Launcher3/quickstep/src/com/android/quickstep/logging/StatsLogCompatManager.kt", "corresponding parameter in the supertype"),
    ("packages/apps/Launcher3/quickstep/src/com/android/quickstep/orientation/SeascapePagedViewHandler.kt", "corresponding parameter in the supertype"),
    ("packages/apps/Launcher3/quickstep/src/com/android/quickstep/util/GroupTask.kt", "corresponding parameter in the supertype"),
    ("packages/apps/Launcher3/quickstep/src/com/android/quickstep/views/DesktopTaskView.kt", "corresponding parameter in the supertype"),
    ("packages/apps/Launcher3/quickstep/src/com/android/quickstep/views/FloatingAppPairBackground.kt", "overrides a deprecated member but is not marked as deprecated itself"),
    ("packages/apps/Launcher3/src/com/android/launcher3/graphics/PreloadIconDelegate.kt", "fun getColor(p0: Int): Int' is deprecated"),
    ("packages/apps/Launcher3/src/com/android/launcher3/model/DbEntry.kt", "fun toURI(): String!' is deprecated"),
    ("packages/apps/Launcher3/src/com/android/launcher3/dragndrop/AddItemActivity.kt", "field label: String!' is deprecated"),
    ("packages/apps/Launcher3/src/com/android/launcher3/display/DisplayControllerImpl.kt", "class Executors : Any' is deprecated"),
    ("packages/apps/Launcher3/src/com/android/launcher3/display/DisplayControllerImpl.kt", "static field MAIN_EXECUTOR: LooperExecutor!' is deprecated"),
    ("packages/apps/Launcher3/src/com/android/launcher3/display/DisplayControllerImpl.kt", "val perDisplayInfo: SparseArray<DisplayInfoContainer>' is deprecated"),
    ("packages/apps/Launcher3/src/com/android/launcher3/deviceprofile/TaskbarDeviceProfileFactory.kt", "fun changeIconSize(iconSizePx: Int): WorkspaceProfile' is deprecated"),
)


def is_migrated_warning_regression(line: str) -> bool:
    if any(marker in line for marker in GLOBAL_MIGRATED_WARNING_MARKERS):
        return True
    return any(path in line and marker in line for path, marker in MIGRATED_WARNING_RULES)


def self_test() -> None:
    assert is_migrated_warning_regression(
        "packages/apps/Launcher3/src/com/android/launcher3/UtilitiesKt.kt:77: "
        "warning: the corresponding parameter in the supertype is named 'attr'."
    )
    assert not is_migrated_warning_regression(
        "packages/apps/Launcher3/src/com/android/launcher3/Unmigrated.kt:77: "
        "warning: the corresponding parameter in the supertype is named 'attr'."
    )
    assert is_migrated_warning_regression(
        "packages/apps/Launcher3/src/com/android/launcher3/Anything.kt:77: "
        "warning: this annotation is currently applied to the value parameter only"
    )
    print("R9_LAUNCHER3_WARNING_GATE_SELF_TEST=PASS")


def classify(line: str) -> str:
    if "[removal]" in line:
        return "removal"
    if "deprecated" in line.lower():
        return "deprecation"
    if "unchecked cast" in line:
        return "unchecked_cast"
    if "type mismatch" in line:
        return "type_mismatch"
    return "other"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("log", type=pathlib.Path, nargs="?")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0

    if args.log is None:
        parser.error("log is required unless --self-test is used")

    if not args.log.is_file():
        print(f"R9_LAUNCHER3_WARNING_GATE=FAIL missing_log={args.log}", file=sys.stderr)
        return 2

    lines = args.log.read_text(encoding="utf-8", errors="replace").splitlines()
    warnings = [line for line in lines if "warning:" in line.lower() or "Warning:" in line]

    categories = collections.Counter(classify(line) for line in warnings)
    fatal: list[str] = []

    for line in warnings:
        if any(marker in line for marker in SABLE_PATH_MARKERS):
            fatal.append(f"SABLE_WARNING {line}")
            continue
        if is_migrated_warning_regression(line):
            fatal.append(f"MIGRATED_WARNING_REGRESSION {line}")

    print(f"R9_LAUNCHER3_WARNING_COUNT={len(warnings)}")
    print(f"R9_LAUNCHER3_DEPRECATION_COUNT={categories['deprecation']}")
    print(f"R9_LAUNCHER3_REMOVAL_COUNT={categories['removal']}")
    print(f"R9_LAUNCHER3_UNCHECKED_CAST_COUNT={categories['unchecked_cast']}")
    print(f"R9_LAUNCHER3_TYPE_MISMATCH_COUNT={categories['type_mismatch']}")

    deprecation_debt = categories["deprecation"] + categories["removal"]
    r8_api37_debt = any(R8_API37_WARNING in line for line in lines)

    if deprecation_debt:
        print(f"R9_LAUNCHER3_UPSTREAM_DEPRECATION_DEBT=REMAINS count={deprecation_debt}")
    else:
        print("R9_LAUNCHER3_UPSTREAM_DEPRECATION_DEBT=ZERO")

    if r8_api37_debt:
        print("R9_LAUNCHER3_R8_API37_DEBT=OPEN")
    else:
        print("R9_LAUNCHER3_R8_API37_DEBT=CLOSED")

    if deprecation_debt or r8_api37_debt:
        print("R9_LAUNCHER3_WARNING_DEBT_STATUS=OPEN")
    else:
        print("R9_LAUNCHER3_WARNING_DEBT_STATUS=CLOSED")

    if fatal:
        for item in fatal:
            print(f"FAIL: {item}", file=sys.stderr)
        print("R9_LAUNCHER3_WARNING_GATE=FAIL", file=sys.stderr)
        return 1

    print("R9_LAUNCHER3_SABLE_WARNING_COUNT=0")
    print("R9_LAUNCHER3_MIGRATED_WARNING_REGRESSIONS=0")
    print("R9_LAUNCHER3_WARNING_MIGRATION_GATE=PASS")
    print("R9_LAUNCHER3_WARNING_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
