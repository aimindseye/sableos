#!/usr/bin/env python3
"""Apply/verify the R9 Sable HOME touch/state ownership overlay.

This layer runs after apply_r9_launcher3_foundation.py. It prevents native
Launcher3 All Apps/workspace gesture interception while the Sable HOME surface
is active, while preserving nav-bar Quickstep Overview/Recents.
"""

from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LAUNCHER_REPO = Path("packages/apps/Launcher3")
PORTRAIT = Path(
    "quickstep/src/com/android/launcher3/uioverrides/touchcontrollers/"
    "PortraitStatesTouchController.java"
)
NO_BUTTON = Path(
    "quickstep/src/com/android/launcher3/uioverrides/touchcontrollers/"
    "NoButtonNavbarToOverviewTouchController.java"
)

COHESION_DIRTY_PATHS = {PORTRAIT.as_posix(), NO_BUTTON.as_posix()}

# Canonical host blob from the immediately preceding frozen WS7 source
# (d836cdb9eba13cff864186ea156a347b7b7cc273). This is the only stale host
# accepted for an in-place cohesion refresh after the activity-context fix.
PREVIOUS_CANONICAL_HOST_BLOBS = {
    "a3bf622a048d399cf4a9ffa89e3cbbdb58f1ac97",
}

PORTRAIT_IMPORT_OLD = (
    "import com.android.launcher3.states.StateAnimationConfig;\n"
)
PORTRAIT_IMPORT_NEW = (
    PORTRAIT_IMPORT_OLD
    + "import com.android.launcher3.sable.SableQuickstepLauncher;\n"
)

PORTRAIT_METHOD_OLD = """    @Override
    protected boolean canInterceptTouch(MotionEvent ev) {
        // If we are swiping to all apps instead of overview, allow it from anywhere.
"""
PORTRAIT_METHOD_NEW = """    @Override
    protected boolean canInterceptTouch(MotionEvent ev) {
        // Sable owns every HOME-facing surface. Direct PortraitStatesTouchController
        // instances are the native Launcher3 NORMAL <-> ALL_APPS path, so they must
        // not steal vertical drags from the full-screen Sable Compose surface.
        // NoButtonNavbarToOverviewTouchController is exempted here and applies its
        // own nav-bar-only guard below so Quickstep Recents remains available.
        if (mLauncher instanceof SableQuickstepLauncher
                && ((SableQuickstepLauncher) mLauncher).isSableSurfaceActive()
                && !(this instanceof NoButtonNavbarToOverviewTouchController)) {
            return false;
        }

        // If we are swiping to all apps instead of overview, allow it from anywhere.
"""

NO_BUTTON_IMPORT_OLD = (
    "import com.android.launcher3.states.StateAnimationConfig;\n"
)
NO_BUTTON_IMPORT_NEW = (
    NO_BUTTON_IMPORT_OLD
    + "import com.android.launcher3.sable.SableQuickstepLauncher;\n"
)

NO_BUTTON_ANCHOR_OLD = """        mDidTouchStartInNavBar = (ev.getEdgeFlags() & EDGE_NAV_BAR) != 0;
        boolean isOneHandedModeActive = (SystemUiProxy.INSTANCE.get(mLauncher)
"""
NO_BUTTON_ANCHOR_NEW = """        mDidTouchStartInNavBar = (ev.getEdgeFlags() & EDGE_NAV_BAR) != 0;

        // On Sable HOME, vertical drags above the navigation edge belong to
        // Start/All Apps/Search. Preserve only the genuine nav-bar gesture path
        // used for Quickstep Overview/Recents.
        if (mLauncher instanceof SableQuickstepLauncher
                && ((SableQuickstepLauncher) mLauncher).isSableSurfaceActive()
                && !mDidTouchStartInNavBar) {
            return false;
        }

        boolean isOneHandedModeActive = (SystemUiProxy.INSTANCE.get(mLauncher)
"""


def load_foundation():
    path = Path(__file__).resolve().with_name("apply_r9_launcher3_foundation.py")
    spec = importlib.util.spec_from_file_location("r9_launcher_foundation", path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"R9_LAUNCHER_COHESION_IMPORT_FAIL={path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"R9_LAUNCHER_COHESION_REPLACE_FAIL={label} count={count}")
    return text.replace(old, new, 1)


def patch_portrait(text: str) -> str:
    text = replace_once(
        text,
        PORTRAIT_IMPORT_OLD,
        PORTRAIT_IMPORT_NEW,
        "portrait-import",
    )
    return replace_once(
        text,
        PORTRAIT_METHOD_OLD,
        PORTRAIT_METHOD_NEW,
        "portrait-intercept",
    )


def patch_no_button(text: str) -> str:
    text = replace_once(
        text,
        NO_BUTTON_IMPORT_OLD,
        NO_BUTTON_IMPORT_NEW,
        "no-button-import",
    )
    return replace_once(
        text,
        NO_BUTTON_ANCHOR_OLD,
        NO_BUTTON_ANCHOR_NEW,
        "no-button-nav-edge",
    )


def apply(source: Path) -> None:
    foundation = load_foundation()
    foundation.verify_tree(source)

    launcher = source / LAUNCHER_REPO
    dirty = foundation.launcher_dirty_paths(launcher)
    if dirty != foundation.FOUNDATION_DIRTY_PATHS:
        raise SystemExit(
            "R9_LAUNCHER_COHESION_PRE_DIRTY_SCOPE_FAIL="
            f"actual={sorted(dirty)!r}"
        )

    portrait = launcher / PORTRAIT
    no_button = launcher / NO_BUTTON

    portrait.write_text(
        patch_portrait(portrait.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    no_button.write_text(
        patch_no_button(no_button.read_text(encoding="utf-8")),
        encoding="utf-8",
    )

    verify(source)
    print("R9_LAUNCHER_COHESION_APPLY=PASS")


def refresh_canonical_host(source: Path) -> None:
    foundation = load_foundation()
    launcher = source / LAUNCHER_REPO

    if foundation.git_head(launcher) != foundation.LAUNCHER3_HEAD:
        raise SystemExit("R9_LAUNCHER_COHESION_REFRESH_HEAD_MISMATCH")

    expected = set(foundation.FOUNDATION_DIRTY_PATHS) | COHESION_DIRTY_PATHS
    actual = foundation.launcher_dirty_paths(launcher)
    if actual != expected:
        raise SystemExit(
            "R9_LAUNCHER_COHESION_REFRESH_DIRTY_SCOPE_FAIL="
            f"expected={sorted(expected)!r} actual={sorted(actual)!r}"
        )

    portrait_text = (launcher / PORTRAIT).read_text(encoding="utf-8")
    no_button_text = (launcher / NO_BUTTON).read_text(encoding="utf-8")
    for needle in (
        "SableQuickstepLauncher",
        "isSableSurfaceActive()",
        "!(this instanceof NoButtonNavbarToOverviewTouchController)",
    ):
        if needle not in portrait_text:
            raise SystemExit(
                f"R9_LAUNCHER_COHESION_REFRESH_PORTRAIT_GUARD_MISSING={needle}"
            )
    for needle in (
        "SableQuickstepLauncher",
        "isSableSurfaceActive()",
        "!mDidTouchStartInNavBar",
    ):
        if needle not in no_button_text:
            raise SystemExit(
                f"R9_LAUNCHER_COHESION_REFRESH_NAV_GUARD_MISSING={needle}"
            )

    host = launcher / foundation.HOST_REL
    actual_host_blob = foundation.worktree_blob(launcher, foundation.HOST_REL)
    if actual_host_blob not in PREVIOUS_CANONICAL_HOST_BLOBS:
        raise SystemExit(
            "R9_LAUNCHER_COHESION_REFRESH_HOST_BLOB_FAIL="
            f"actual={actual_host_blob}"
        )

    host.write_bytes(foundation.HOST_SOURCE.read_bytes())
    verify(source)
    print(
        "R9_LAUNCHER_COHESION_CANONICAL_HOST_REFRESH=PASS "
        f"from={actual_host_blob}"
    )


def verify(source: Path) -> None:
    foundation = load_foundation()
    launcher = source / LAUNCHER_REPO

    if foundation.git_head(launcher) != foundation.LAUNCHER3_HEAD:
        raise SystemExit("R9_LAUNCHER_COHESION_HEAD_MISMATCH")

    expected = set(foundation.FOUNDATION_DIRTY_PATHS) | COHESION_DIRTY_PATHS
    actual = foundation.launcher_dirty_paths(launcher)
    if actual != expected:
        raise SystemExit(
            "R9_LAUNCHER_COHESION_FINAL_DIRTY_SCOPE_FAIL="
            f"expected={sorted(expected)!r} actual={sorted(actual)!r}"
        )

    host = launcher / foundation.HOST_REL
    if host.read_bytes() != foundation.HOST_SOURCE.read_bytes():
        raise SystemExit("R9_LAUNCHER_COHESION_HOST_DRIFT")

    host_text = host.read_text(encoding="utf-8")
    required_host = (
        "fun isSableSurfaceActive(): Boolean",
        "private fun isCommittedOverviewState(state: LauncherState): Boolean",
        "LauncherState.OVERVIEW_MODAL_TASK",
        "LauncherState.OVERVIEW_SPLIT_SELECT",
        "protected override fun shouldDisableBackGesture(): Boolean",
        "isSableSurfaceActive() && canSableNavigateBack",
        "sableView?.bringToFront()",
        "LauncherState.ALL_APPS ->",
        "stateManager.goToState(LauncherState.NORMAL, false)",
        "readGlobalSableAppearance(",
        "writeGlobalSableAppearance(",
        "onOpenSystemSettings = ::openSystemSettings",
    )
    for needle in required_host:
        if needle not in host_text:
            raise SystemExit(f"R9_LAUNCHER_COHESION_HOST_MISSING={needle}")

    portrait_text = (launcher / PORTRAIT).read_text(encoding="utf-8")
    no_button_text = (launcher / NO_BUTTON).read_text(encoding="utf-8")

    for needle in (
        "SableQuickstepLauncher",
        "isSableSurfaceActive()",
        "!(this instanceof NoButtonNavbarToOverviewTouchController)",
        "return false;",
    ):
        if needle not in portrait_text:
            raise SystemExit(f"R9_LAUNCHER_PORTRAIT_GUARD_MISSING={needle}")

    for needle in (
        "SableQuickstepLauncher",
        "isSableSurfaceActive()",
        "!mDidTouchStartInNavBar",
        "return false;",
    ):
        if needle not in no_button_text:
            raise SystemExit(f"R9_LAUNCHER_NAV_GUARD_MISSING={needle}")

    print("R9_SABLE_NATIVE_ALL_APPS_TOUCH_ESCAPE=PASS_BLOCKED")
    print("R9_SABLE_START_VERTICAL_DRAG_OWNERSHIP=PASS")
    print("R9_SABLE_HINT_STATE_PRESENTATION=PASS_COVERED_BY_SABLE")
    print("R9_SABLE_SUBSURFACE_BACK_GESTURE=PASS_ENABLED")
    print("R9_QUICKSTEP_NAVBAR_OVERVIEW_PATH=PASS_PRESERVED")
    print("R9_LAUNCHER_COHESION=PASS")


def self_test() -> None:
    portrait = PORTRAIT_IMPORT_OLD + PORTRAIT_METHOD_OLD
    no_button = NO_BUTTON_IMPORT_OLD + NO_BUTTON_ANCHOR_OLD

    p = patch_portrait(portrait)
    n = patch_no_button(no_button)

    if "isSableSurfaceActive()" not in p:
        raise SystemExit("R9_LAUNCHER_COHESION_SELF_TEST_PORTRAIT_FAIL")
    if "!mDidTouchStartInNavBar" not in n:
        raise SystemExit("R9_LAUNCHER_COHESION_SELF_TEST_NO_BUTTON_FAIL")

    print("R9_LAUNCHER_COHESION_SELF_TEST=PASS")
    print("SELF_TEST_REAL_SOURCE_MUTATION=NONE")
    print("SELF_TEST_BUILD=NONE")
    print("SELF_TEST_DEVICE_CONTACT=NONE")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "mode",
        nargs="?",
        choices=("apply", "verify", "refresh-canonical-host"),
    )
    parser.add_argument("--source", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0

    if args.mode is None or args.source is None:
        parser.error("mode and --source are required unless --self-test is used")

    source = args.source.resolve()
    if not (source / ".repo").exists():
        raise SystemExit(f"NOT_ANDROID_REPO_ROOT={source}")

    if args.mode == "apply":
        apply(source)
    elif args.mode == "refresh-canonical-host":
        refresh_canonical_host(source)
    else:
        verify(source)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
