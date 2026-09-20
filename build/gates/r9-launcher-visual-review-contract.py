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
    presentation_build = (
        ROOT / "apps/r8/android/sablestart-presentation-check/build.gradle.kts"
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
    forbid(
        module_build,
        "androidx.core:core-ktx:1.17.0",
        "R9_VISUAL_REVIEW_UNVERIFIED_ANDROIDX_CORE",
    )
    require(
        module_build,
        "ignoreTestSources = true",
        "R9_VISUAL_REVIEW_LINT_IGNORES_TEST_SOURCES",
    )
    forbid(
        presentation_build,
        "androidx.core:core-ktx:1.17.0",
        "R9_PRESENTATION_UNVERIFIED_ANDROIDX_CORE",
    )
    lifecycle_modules = (
        "lifecycle-common",
        "lifecycle-common-java8",
        "lifecycle-common-jvm",
        "lifecycle-process",
        "lifecycle-runtime",
        "lifecycle-runtime-android",
        "lifecycle-runtime-ktx",
        "lifecycle-runtime-ktx-android",
    )
    for build_text, label in (
        (module_build, "R9_VISUAL_REVIEW"),
        (presentation_build, "R9_PRESENTATION"),
    ):
        require(
            build_text,
            'implementation("androidx.core:core-ktx:1.16.0")',
            f"{label}_VERIFIED_CORE_CONSTRAINT",
        )
        for collection_module in (
            "collection",
            "collection-jvm",
            "collection-ktx",
        ):
            require(
                build_text,
                f'implementation("androidx.collection:{collection_module}:1.5.0")',
                f"{label}_VERIFIED_COLLECTION_CONSTRAINT",
            )
        for lifecycle_module in lifecycle_modules:
            require(
                build_text,
                f'implementation("androidx.lifecycle:{lifecycle_module}:2.9.4")',
                f"{label}_VERIFIED_LIFECYCLE_CONSTRAINT",
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
        activity,
        "ActivityResultContracts.RequestMultiplePermissions()",
        "R9_VISUAL_REVIEW_ACTIVITY_RESULT_PERMISSIONS",
    )
    forbid(
        activity,
        "onRequestPermissionsResult(",
        "R9_VISUAL_REVIEW_DEPRECATED_PERMISSION_CALLBACK",
    )
    require(
        production_ui,
        "context.getSystemService(LauncherApps::class.java)",
        "R9_PRODUCTION_REAL_ICON_RESOLVER",
    )
    require(
        production_ui,
        "activityInfo.getBadgedIcon(densityDpi)",
        "R9_PRODUCTION_REAL_ICON_DRAWABLE",
    )
    require(
        production_ui,
        "app.stableKey() in primaryKeys || isSettingsApp(app)",
        "R9_START_NO_PRIMARY_FAVORITE_DUPLICATION",
    )
    require(
        production_ui,
        "if (quickApps.isNotEmpty())",
        "R9_START_EMPTY_FAVORITES_HIDDEN",
    )
    require(
        production_ui,
        "modifier = Modifier.fillMaxWidth()",
        "R9_START_ODD_TILE_SPANS_ROW",
    )
    require(
        production_ui,
        ".height(96.dp)",
        "R9_START_COMPACT_TILE_HEIGHT",
    )
    require(
        production_ui,
        'text = "search + command"',
        "R9_START_METRO_SEARCH_TREATMENT",
    )
    require(
        production_ui,
        'text = "appearance"',
        "R9_START_APPEARANCE_SHORTCUT",
    )
    require(
        production_ui,
        "StartNavigationRow(",
        "R9_START_COMPACT_NAVIGATION",
    )
    require(
        production_ui,
        "BasicTextField(",
        "R9_SEARCH_FLAT_INPUT",
    )
    forbid(
        production_ui,
        "OutlinedTextField(",
        "R9_SEARCH_NO_MATERIAL_OUTLINED_FIELD",
    )
    require(
        production_ui,
        'text = "search apps + Sable actions"',
        "R9_SEARCH_SABLE_PLACEHOLDER",
    )
    require(
        production_ui,
        'text = "peek"',
        "R9_PEEK_SABLE_IDENTITY",
    )
    require(
        production_ui,
        'text = "open"',
        "R9_PEEK_FLAT_OPEN_ACTION",
    )
    require(
        production_ui,
        'label = if (isPinned) "unpin from favorites" else "pin to favorites"',
        "R9_PEEK_FAVORITE_ACTION",
    )
    require(
        production_ui,
        'label = "permissions + app info"',
        "R9_PEEK_PRIVACY_ACTION",
    )
    require(
        production_ui,
        "LocalDatumRow(",
        "R9_LOCAL_CONTEXT_FLAT_ROWS",
    )
    require(
        production_ui,
        'text = "enable local data"',
        "R9_LOCAL_CONTEXT_FLAT_PERMISSION_ACTION",
    )
    require(
        production_ui,
        'text = "weather + tasks · provider not configured"',
        "R9_LOCAL_CONTEXT_PROVIDER_STATUS",
    )
    require(
        production_ui,
        'text = "local only · no ambient network search"',
        "R9_LOCAL_CONTEXT_NETWORK_TRUTH",
    )
    forbid(
        production_ui,
        "LiveCard(",
        "R9_LOCAL_CONTEXT_OLD_CARD_SURFACE",
    )
    forbid(
        production_ui,
        'text = "Sable Peek"',
        "R9_PEEK_OLD_MATERIAL_SHEET_COPY",
    )
    require(
        production_ui,
        "color = MaterialTheme.colorScheme.primary",
        "R9_SEARCH_COMMAND_ACCENT",
    )
    require(
        activity,
        "info.componentName.packageName == packageName",
        "R9_VISUAL_REVIEW_HOST_FILTERED",
    )

    mac_runner = (
        ROOT / "build/macos/prepare-r9-launcher-visual-review.sh"
    ).read_text()
    require(
        mac_runner,
        'GRADLE_OFFLINE=NO',
        "R9_VISUAL_REVIEW_MAC_NETWORK_MODE",
    )
    require(
        mac_runner,
        'GRADLE_OFFLINE=YES',
        "R9_VISUAL_REVIEW_MAC_OFFLINE_MODE",
    )
    forbid(
        mac_runner,
        'GRADLE_NETWORK_ARGS=()',
        "R9_VISUAL_REVIEW_MAC_BASH3_EMPTY_ARRAY",
    )
    forbid(
        mac_runner,
        ":sablestart-visual-review:lintDebug",
        "R9_VISUAL_REVIEW_MAC_BUILD_BLOCKED_BY_LINT",
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
    print("R9_VISUAL_REVIEW_VERIFIED_ANDROIDX_GRAPH=PASS")
    print("R9_VISUAL_REVIEW_VERIFIED_ANDROIDX_CONSTRAINTS=PASS")
    print("R9_VISUAL_REVIEW_ACTIVITY_RESULT_PERMISSIONS=PASS")
    print("R9_VISUAL_REVIEW_LINT_TEST_SURFACE=PASS")
    print("R9_VISUAL_REVIEW_PRODUCTION_SCREEN=PASS")
    print("R9_VISUAL_REVIEW_NOT_HOME=PASS")
    print("R9_VISUAL_REVIEW_ABSENT_FROM_PRODUCT_GRAPH=PASS")
    print("R9_PRODUCTION_REAL_ICONS=PASS")
    print("R9_START_NO_PRIMARY_FAVORITE_DUPLICATION=PASS")
    print("R9_START_EMPTY_FAVORITES_HIDDEN=PASS")
    print("R9_START_ODD_TILE_LAYOUT=PASS")
    print("R9_START_COMPACT_METRO_HIERARCHY=PASS")
    print("R9_SEARCH_FLAT_METRO_INPUT=PASS")
    print("R9_SEARCH_COMMAND_APP_HIERARCHY=PASS")
    print("R9_PEEK_FLAT_CONTEXTUAL_LAYER=PASS")
    print("R9_PEEK_ACTION_HIERARCHY=PASS")
    print("R9_LOCAL_CONTEXT_FLAT_ROWS=PASS")
    print("R9_LOCAL_CONTEXT_TRUTHFUL_STATUS=PASS")
    print("R9_VISUAL_REVIEW_HOST_FILTERED=PASS")
    local_ci = (ROOT / "build/local-ci/run.sh").read_text()
    require(
        local_ci,
        ":sablestart-visual-review:lintDebug",
        "R9_VISUAL_REVIEW_LOCAL_CI_LINT_GATE",
    )

    print("R9_VISUAL_REVIEW_MAC_BASH3_COMPAT=PASS")
    print("R9_VISUAL_REVIEW_MAC_BUILD_DECOUPLED_FROM_LINT=PASS")
    print("R9_VISUAL_REVIEW_LOCAL_CI_LINT_GATE=PASS")
    print("R9_L13_VISUAL_REVIEW_CONTRACT=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
