#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]


def fail(label: str, detail: str) -> None:
    print(f"{label}=FAIL {detail}", file=sys.stderr)
    raise SystemExit(1)


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        fail(label, f"missing={needle!r}")


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        fail(label, f"forbidden={needle!r}")


def main() -> int:
    settings = (ROOT / "apps/r8/android/settings.gradle.kts").read_text()
    module_build = (
        ROOT / "apps/r8/android/sablestart-visual-review/build.gradle.kts"
    ).read_text()
    manifest = (
        ROOT
        / "apps/r8/android/sablestart-visual-review/src/main/AndroidManifest.xml"
    ).read_text()
    activity = (
        ROOT
        / "apps/r8/android/sablestart-visual-review/src/main/java"
        / "org/sableos/start/visualreview/R9LauncherVisualReviewActivity.kt"
    ).read_text()
    production_ui = (
        ROOT
        / "src/android/packages/apps/SableStart/src/com/sable/start/ui"
        / "SableStartScreen.kt"
    ).read_text()

    require(
        settings,
        'include(":sablestart-visual-review")',
        "R9_VISUAL_REVIEW_MODULE_REGISTERED",
    )
    require(
        module_build,
        'implementation(project(":sablestart-presentation-check"))',
        "R9_VISUAL_REVIEW_PRODUCTION_SOURCE_DEPENDENCY",
    )
    require(
        activity,
        "SableStartScreen(",
        "R9_VISUAL_REVIEW_PRODUCTION_SCREEN",
    )
    require(
        activity,
        "launcherApps.getActivityList",
        "R9_VISUAL_REVIEW_ANDROID_INVENTORY",
    )
    require(
        production_ui,
        "context.getSystemService(LauncherApps::class.java)",
        "R9_PRODUCTION_REAL_ICON_RESOLVER",
    )
    require(
        production_ui,
        "activityInfo.getIcon(densityDpi)",
        "R9_PRODUCTION_REAL_ICON_DRAWABLE",
    )

    forbid(
        manifest,
        "android.intent.category.HOME",
        "R9_VISUAL_REVIEW_NOT_HOME",
    )
    forbid(
        manifest,
        "android.app.role.HOME",
        "R9_VISUAL_REVIEW_NOT_HOME_ROLE",
    )
    forbid(
        activity,
        "SableQuickstepLauncher",
        "R9_VISUAL_REVIEW_NO_QUICKSTEP_REIMPLEMENTATION",
    )

    product_surfaces = [
        ROOT / "product/r8/panther/r8-product.mk",
        ROOT / "apps/r8/export-panther-app-bundle.sh",
        ROOT / "build/panther/build-r8-final-ui.sh",
        ROOT / "build/panther/prepare-r8-final-ui.sh",
    ]
    for product_surface in product_surfaces:
        text = product_surface.read_text()
        forbid(
            text,
            "sablestart-visual-review",
            "R9_VISUAL_REVIEW_ABSENT_FROM_PRODUCT_GRAPH",
        )
        forbid(
            text,
            "org.sableos.start.visualreview",
            "R9_VISUAL_REVIEW_ABSENT_FROM_PRODUCT_GRAPH",
        )

    print("R9_VISUAL_REVIEW_MODULE_REGISTERED=PASS")
    print("R9_VISUAL_REVIEW_PRODUCTION_SOURCE_DEPENDENCY=PASS")
    print("R9_VISUAL_REVIEW_PRODUCTION_SCREEN=PASS")
    print("R9_VISUAL_REVIEW_NOT_HOME=PASS")
    print("R9_VISUAL_REVIEW_ABSENT_FROM_PRODUCT_GRAPH=PASS")
    print("R9_PRODUCTION_REAL_ICONS=PASS")
    print("R9_L9_VISUAL_REVIEW_CONTRACT=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
