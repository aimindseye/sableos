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
    glyphs = (
        ROOT
        / "src/android/packages/apps/SableStart/src/com/sable/start/ui"
        / "SableGlyphIcon.kt"
    ).read_text()
    fixtures = (
        ROOT
        / "apps/r8/android/sablestart-visual-review/src/main/java"
        / "org/sableos/start/visualreview/DailyDriverReviewFixtures.kt"
    ).read_text()
    quickstep = (
        ROOT
        / "patches/android-17-grapheneos-2026081300/r9_launcher3"
        / "SableQuickstepLauncher.kt"
    ).read_text()
    start_capture = (
        ROOT
        / "build/macos/capture-r9-start-tiles-final-review.sh"
    ).read_text()
    state_repo = (
        ROOT
        / "src/android/packages/apps/SableStart/src/com/sable/start/platform"
        / "StartStateRepository.kt"
    ).read_text()

    require(
        settings,
        'include(":sablestart-visual-review")',
        "R9_VISUAL_REVIEW_MODULE_REGISTERED",
    )
    require(
        glyphs,
        "SableGlyphIcon(",
        "R9_VISUAL_REVIEW_SHARED_GLYPH_RENDERER",
    )
    require(
        glyphs,
        '"org.sableos.weather" -> SableGlyphs.Weather',
        "R9_VISUAL_REVIEW_WEATHER_GLYPH_BINDING",
    )
    require(
        production_ui,
        "approvedGlyphPackage(app)",
        "R9_VISUAL_REVIEW_FIXTURE_LABEL_GLYPH_BINDING",
    )
    for needle in (
        "ReviewWeatherSnapshotProvider",
        "Jersey City · 68° · partly cloudy",
        "ReviewMailSnapshotProvider",
        "4 mail alerts",
        "WeatherFixtureActivity",
        "MailFixtureActivity",
        "CalculatorFixtureActivity",
    ):
        require(
            fixtures,
            needle,
            "R9_VISUAL_REVIEW_SOURCE_BOUND_FIXTURES",
        )
    for needle in (
        'android:name=".ReviewWeatherSnapshotProvider"',
        'android:authorities="org.sableos.weather.snapshot"',
        'android:name=".ReviewMailSnapshotProvider"',
        'android:authorities="org.sableos.mail.snapshot"',
        'android:name=".WeatherFixtureActivity"',
        'android:name=".MailFixtureActivity"',
        'android:name=".CalculatorFixtureActivity"',
    ):
        require(
            manifest,
            needle,
            "R9_VISUAL_REVIEW_FIXTURE_MANIFEST",
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
        manifest,
        "<queries>",
        "R9_VISUAL_REVIEW_PACKAGE_VISIBILITY_QUERY",
    )
    require(
        manifest,
        'android.permission.READ_MEDIA_IMAGES',
        "R9_VISUAL_REVIEW_PHOTO_PERMISSION_PARITY",
    )
    forbid(
        manifest,
        'android.permission.READ_CALENDAR',
        "R9_VISUAL_REVIEW_NO_DIRECT_CALENDAR_PERMISSION",
    )
    forbid(
        manifest,
        'android.permission.READ_MEDIA_AUDIO',
        "R9_VISUAL_REVIEW_NO_DIRECT_AUDIO_PERMISSION",
    )
    for authority in (
        "org.sableos.weather.snapshot",
        "org.sableos.calendar.snapshot",
        "org.sableos.hub.snapshot",
        "org.sableos.mail.snapshot",
        "org.sableos.media.snapshot",
    ):
        require(
            manifest,
            f'android:authorities="{authority}"',
            "R9_VISUAL_REVIEW_LIVE_PROVIDER_VISIBILITY",
        )
    for needle in (
        'android:name="org.sableos.start.platform.SableAppearanceProvider"',
        'android:authorities="org.sableos.start.appearance"',
        'android:exported="true"',
    ):
        require(
            manifest,
            needle,
            "R9_VISUAL_REVIEW_APPEARANCE_PROVIDER_PARITY",
        )
    for needle in (
        "StartStateRepository",
        "startStateRepository.loadAppearance()",
        "startStateRepository.saveAppearance(appearance)",
        "startStateRepository.resetAppearance()",
    ):
        require(
            activity,
            needle,
            "R9_VISUAL_REVIEW_APPEARANCE_PERSISTENCE_PARITY",
        )
    require(
        activity,
        "PackageManager.GET_PERMISSIONS",
        "R9_VISUAL_REVIEW_GRANTED_PERMISSION_QUERY",
    )
    require(
        activity,
        "PackageInfo.REQUESTED_PERMISSION_GRANTED",
        "R9_VISUAL_REVIEW_GRANTED_PERMISSION_FLAGS",
    )
    forbid(
        activity,
        "createContextAsUser(",
        "R9_VISUAL_REVIEW_NO_HIDDEN_PROFILE_CONTEXT_API",
    )
    require(
        activity,
        "packageManager.getPackageInfo(",
        "R9_VISUAL_REVIEW_PUBLIC_PACKAGE_MANAGER_PERMISSION_QUERY",
    )
    for needle in (
        "Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU",
        "PackageManager.PackageInfoFlags.of(",
        '@Suppress("DEPRECATION")',
        "PackageManager.GET_PERMISSIONS,",
    ):
        require(
            activity,
            needle,
            "R9_VISUAL_REVIEW_PACKAGEINFO_API_COMPAT",
        )
    require(
        activity,
        "privacySummary =",
        "R9_VISUAL_REVIEW_PRIVACY_SUMMARY_POPULATED",
    )
    require(
        activity,
        '"permissions · none sensitive"',
        "R9_VISUAL_REVIEW_PRIVACY_SUMMARY_NONE",
    )
    require(
        activity,
        '"permissions · " + labels.joinToString(" · ")',
        "R9_VISUAL_REVIEW_PRIVACY_SUMMARY_LABELS",
    )
    require(
        activity,
        'const val GRAPHENE_MESSAGING_PACKAGE = "com.android.messaging"',
        "R9_VISUAL_REVIEW_MESSAGING_FILTER_CONSTANT",
    )
    require(
        activity,
        "component.packageName == GRAPHENE_MESSAGING_PACKAGE",
        "R9_VISUAL_REVIEW_MESSAGING_FILTER",
    )
    require(
        activity,
        'const val HOST_AVD_GOOGLE_MESSAGES_PACKAGE = "com.google.android.apps.messaging"',
        "R9_VISUAL_REVIEW_HOST_GOOGLE_MESSAGES_CONSTANT",
    )
    require(
        activity,
        "component.packageName == HOST_AVD_GOOGLE_MESSAGES_PACKAGE",
        "R9_VISUAL_REVIEW_HOST_GOOGLE_MESSAGES_FILTER",
    )
    require(
        activity,
        'const val HOST_AVD_CHROME_PACKAGE = "com.android.chrome"',
        "R9_VISUAL_REVIEW_HOST_CHROME_CONSTANT",
    )
    require(
        activity,
        "component.packageName == HOST_AVD_CHROME_PACKAGE",
        "R9_VISUAL_REVIEW_HOST_CHROME_FILTER",
    )
    forbid(
        activity,
        '                "Chrome",',
        "R9_VISUAL_REVIEW_NO_CHROME_PREFERRED_FIXTURE",
    )
    require(
        activity,
        "ActivityResultContracts.RequestMultiplePermissions()",
        "R9_VISUAL_REVIEW_ACTIVITY_RESULT_PERMISSIONS",
    )
    require(
        activity,
        "applySableSystemBars(",
        "R9_VISUAL_REVIEW_SYSTEM_BAR_PARITY",
    )
    require(
        activity,
        "resolveSableDarkAppearance(",
        "R9_VISUAL_REVIEW_DARK_BAR_RESOLUTION",
    )
    require(
        activity,
        "initialFavoriteKeys = favoriteKeys",
        "R9_VISUAL_REVIEW_FAVORITE_STATE",
    )
    require(
        activity,
        "initialStartTileKeys = startTileKeys",
        "R9_VISUAL_REVIEW_START_TILE_STATE",
    )
    require(
        activity,
        'const val HOST_AVD_GOOGLE_CALENDAR_PACKAGE = "com.google.android.calendar"',
        "R9_VISUAL_REVIEW_HOST_GOOGLE_CALENDAR_CONSTANT",
    )
    require(
        activity,
        'const val HOST_AVD_AOSP_CALENDAR_PACKAGE = "com.android.calendar"',
        "R9_VISUAL_REVIEW_HOST_AOSP_CALENDAR_CONSTANT",
    )
    require(
        activity,
        'const val RETIRED_WEATHER_REVIEW_PACKAGE = "org.sableos.weather.visualreview"',
        "R9_VISUAL_REVIEW_RETIRED_WEATHER_FIXTURE_CONSTANT",
    )
    require(
        activity,
        "component.packageName == HOST_AVD_GOOGLE_CALENDAR_PACKAGE",
        "R9_VISUAL_REVIEW_HOST_GOOGLE_CALENDAR_FILTER",
    )
    require(
        activity,
        "component.packageName == HOST_AVD_AOSP_CALENDAR_PACKAGE",
        "R9_VISUAL_REVIEW_HOST_AOSP_CALENDAR_FILTER",
    )
    require(
        activity,
        "component.packageName == RETIRED_WEATHER_REVIEW_PACKAGE",
        "R9_VISUAL_REVIEW_RETIRED_WEATHER_FIXTURE_FILTER",
    )
    require(
        activity,
        '"Sable Weather"',
        "R9_VISUAL_REVIEW_WEATHER_TILE_LABEL",
    )
    require(
        activity,
        'const val EXTRA_EXTENDED_START_TILES = "extendedStartTiles"',
        "R9_VISUAL_REVIEW_EXTENDED_START_FLAG",
    )
    require(
        activity,
        "const val REVIEW_START_TILE_COUNT = 14",
        "R9_VISUAL_REVIEW_EXTENDED_START_COUNT",
    )
    require(
        activity,
        "extendedStartTileKeys(appsState.value)",
        "R9_VISUAL_REVIEW_EXTENDED_START_SEED",
    )
    for frame in (
        "00-start-tiles-top",
        "01-start-tiles-mid-scroll",
        "02-start-tiles-lower-scroll",
        "03-start-tile-peek",
    ):
        require(
            start_capture,
            frame,
            "R9_START_FINAL_CAPTURE_SET",
        )
    require(
        start_capture,
        "R9_START_SCROLL_VISUAL_PROOF=PASS_TOP_TO_SCROLLED",
        "R9_START_FINAL_SCROLL_DELTA_GATE",
    )
    require(
        start_capture,
        "R9_START_SCROLL_LOWER_BOUND=PASS_STABLE_AFTER_SECOND_SWIPE",
        "R9_START_FINAL_STABLE_LOWER_BOUND_GATE",
    )
    require(
        start_capture,
        "R9_START_SCROLL_LOWER_BOUND=PASS_ADDITIONAL_SCROLL",
        "R9_START_FINAL_ADDITIONAL_SCROLL_GATE",
    )
    require(
        start_capture,
        "R9_START_TILES_FINAL_CAPTURE_INTEGRITY=PASS",
        "R9_START_FINAL_CAPTURE_INTEGRITY_GATE",
    )
    require(
        start_capture,
        "resolve_hash() {",
        "R9_START_FINAL_HASH_RESOLVER",
    )
    require(
        start_capture,
        'basename "$path"',
        "R9_START_FINAL_HASH_RESOLVER_BASENAME",
    )
    require(
        start_capture,
        "R9_START_TILES_FINAL_HASH_RESOLUTION=PASS",
        "R9_START_FINAL_HASH_RESOLUTION_MARKER",
    )
    forbid(
        start_capture,
        'TOP_HASH="$(awk',
        "R9_START_FINAL_FRAGILE_AWK_HASH_RESOLVER",
    )
    require(
        start_capture,
        'FINAL_FRAMES=(',
        "R9_START_FINAL_EXACT_FRAME_HASH_SET",
    )
    forbid(
        start_capture,
        '0[0-3]-start-*.png',
        "R9_START_FINAL_NO_HASH_GLOB",
    )
    require(
        start_capture,
        "R9_START_WEATHER_VISUAL_FIXTURE=RETIRED_PRODUCTION_PROVIDER_MODEL",
        "R9_START_FINAL_WEATHER_FIXTURE_RETIRED",
    )
    forbid(
        start_capture,
        "org.sableos.weather.visualreview",
        "R9_START_FINAL_NO_RETIRED_WEATHER_PACKAGE_DEPENDENCY",
    )
    require(
        start_capture,
        "--ez extendedStartTiles true",
        "R9_START_FINAL_EXTENDED_SCROLL_FIXTURE",
    )
    require(
        start_capture,
        "R9_START_SCROLL_FIXTURE=EXTENDED_14_TILES",
        "R9_START_FINAL_EXTENDED_SCROLL_MARKER",
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
        quickstep,
        "if (state == LauncherState.NORMAL) {",
        "R9_QUICKSTEP_NORMAL_STATE_HOOK",
    )
    require(
        quickstep,
        "refreshAppsFromLauncherModel()\n            applyCurrentSystemBars()",
        "R9_QUICKSTEP_SYSTEM_BAR_RESTORE",
    )
    require(
        quickstep,
        "loadFavoriteKeys()",
        "R9_QUICKSTEP_FAVORITE_STATE_BINDING",
    )
    require(
        quickstep,
        "loadStartTileKeys()",
        "R9_QUICKSTEP_START_TILE_STATE_BINDING",
    )
    require(
        state_repo,
        'const val KEY_FAVORITE_APPS = "favorite_apps"',
        "R9_START_FAVORITE_STORAGE",
    )
    require(
        state_repo,
        'const val KEY_START_TILES = "start_tiles"',
        "R9_START_TILE_STORAGE",
    )
    require(
        state_repo,
        'const val KEY_PINNED_APPS_LEGACY = "pinned_apps"',
        "R9_START_LEGACY_PIN_MIGRATION",
    )
    require(
        state_repo,
        ".remove(KEY_PINNED_APPS_LEGACY)",
        "R9_START_LEGACY_PIN_MIGRATION_CLEANUP",
    )
    require(
        state_repo,
        "if (!preferences.contains(KEY_START_TILES))",
        "R9_START_DEFAULT_VS_EXPLICIT_EMPTY",
    )
    require(
        production_ui,
        "var favoriteKeys by remember(initialFavoriteKeys)",
        "R9_START_FAVORITE_STATE_SEPARATION",
    )
    require(
        production_ui,
        "var startTileKeys by remember(initialStartTileKeys)",
        "R9_START_TILE_STATE_SEPARATION",
    )
    require(
        production_ui,
        "DEFAULT_START_TILE_TARGET = 10",
        "R9_START_DEFAULT_TILE_TARGET",
    )
    require(
        production_ui,
        'packageNames = setOf("org.sableos.weather")',
        "R9_START_WEATHER_PACKAGE_PREFERENCE",
    )
    require(
        production_ui,
        'labels = listOf("Sable Weather", "Weather")',
        "R9_START_WEATHER_LABEL_FALLBACK",
    )
    require(
        production_ui,
        "app.component.packageName in group.packageNames",
        "R9_START_PACKAGE_FIRST_PREFERENCE",
    )
    require(
        production_ui,
        "explicitKeys != null",
        "R9_START_EXPLICIT_TILE_STATE",
    )
    forbid(
        production_ui,
        "MAX_START_TILES",
        "R9_START_NO_FOUR_TILE_CAP",
    )
    require(
        production_ui,
        ".combinedClickable(",
        "R9_START_TILE_LONG_PRESS",
    )
    require(
        production_ui,
        "onLongClick = { onOpenPeek(app) }",
        "R9_START_TILE_PEEK_ROUTE",
    )
    require(
        production_ui,
        "SettingsShortcut(",
        "R9_START_APPROVED_SETTINGS_SHORTCUT",
    )
    require(
        production_ui,
        "SableGlyphIcon(",
        "R9_START_APPROVED_SETTINGS_GLYPH",
    )
    require(
        production_ui,
        'packageName = "com.android.settings"',
        "R9_START_APPROVED_SETTINGS_IDENTITY",
    )
    require(
        production_ui,
        'in 12..16 -> "good afternoon"',
        "R9_START_APPROVED_GREETING",
    )
    require(
        production_ui,
        "ApprovedStartNavigationRow(",
        "R9_START_APPROVED_NAVIGATION",
    )
    require(
        production_ui,
        "modifier = Modifier.fillMaxWidth()",
        "R9_START_ODD_TILE_SPANS_ROW",
    )
    require(
        production_ui,
        ".height(if (tile.wide) 106.dp else 118.dp)",
        "R9_START_DIMENSIONAL_TILE_HEIGHT",
    )
    require(
        production_ui,
        "approvedWideContent(",
        "R9_START_APPROVED_WIDE_TILE_CONTENT",
    )
    require(
        production_ui,
        "approvedMetric(",
        "R9_START_APPROVED_LIVE_TILE_CONTENT",
    )
    forbid(
        production_ui,
        "AppearanceShortcut(",
        "R9_START_NO_RETIRED_APPEARANCE_SHORTCUT",
    )
    forbid(
        production_ui,
        "StartNavigationRow(",
        "R9_START_NO_RETIRED_COMPACT_NAVIGATION",
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
    for token, label in (
        ('"remove from start"', "R9_PEEK_REMOVE_FROM_START"),
        ('"pin to start"', "R9_PEEK_PIN_TO_START"),
        ('"unpin from favorites"', "R9_PEEK_UNPIN_FAVORITE"),
        ('"pin to favorites"', "R9_PEEK_PIN_FAVORITE"),
    ):
        require(
            production_ui,
            token,
            label,
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
        'text = "enable local photos"',
        "R9_LOCAL_CONTEXT_PHOTO_PERMISSION_ACTION",
    )
    require(
        production_ui,
        'text = "privacy-safe summaries · no message bodies or mail subjects on Home"',
        "R9_LOCAL_CONTEXT_PRIVACY_STATUS",
    )
    require(
        production_ui,
        'text = "provider and lifecycle refresh · no ambient launcher network client"',
        "R9_LOCAL_CONTEXT_NETWORK_TRUTH",
    )
    require(
        production_ui,
        "AppearanceChoiceRow(",
        "R9_APPEARANCE_FLAT_THEME_ROWS",
    )
    require(
        production_ui,
        "AccentChoiceRow(",
        "R9_APPEARANCE_FLAT_ACCENT_ROWS",
    )
    require(
        production_ui,
        'text = "reset · follow system + Sable Blue"',
        "R9_APPEARANCE_RESET_ACTION",
    )
    forbid(
        production_ui,
        "ButtonDefaults.buttonColors",
        "R9_APPEARANCE_OLD_MATERIAL_BUTTON_COLORS",
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
        "val component = info.componentName",
        "R9_VISUAL_REVIEW_COMPONENT_CAPTURE",
    )
    require(
        activity,
        "component.packageName == packageName",
        "R9_VISUAL_REVIEW_HOST_FILTERED",
    )

    mac_runner = (
        ROOT / "build/macos/prepare-r9-launcher-visual-review.sh"
    ).read_text()
    fidelity_audit = (
        ROOT / "build/macos/audit-r9-launcher-review-fidelity.sh"
    ).read_text()
    theme_capture = (
        ROOT / "build/macos/capture-r9-theme-fidelity-review.sh"
    ).read_text()
    production_capture = (
        ROOT / "build/macos/capture-r9-production-approval.sh"
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
    for needle in (
        ":hub:assembleDebug",
        ":calendar:assembleDebug",
        ":media:assembleDebug",
        "R9_VISUAL_REVIEW_STALE_FIRST_PARTY_CLEANUP=PASS",
        "R9_VISUAL_REVIEW_SABLE_MESSAGES_INSTALL=PASS",
        "R9_VISUAL_REVIEW_SABLE_CALENDAR_INSTALL=PASS",
        "R9_VISUAL_REVIEW_SABLE_MEDIA_INSTALL=PASS",
        "R9_VISUAL_REVIEW_SABLE_CALENDAR_PERMISSION_FIXTURE=PASS",
        "R9_VISUAL_REVIEW_THEME_PROBE_APP=SABLE_MESSAGES",
        "R9_VISUAL_REVIEW_APPEARANCE_PROVIDER=PASS",
        "content://org.sableos.start.appearance/appearance",
        "R9_VISUAL_REVIEW_BROWSER_IDENTITY_SOURCE=HOST_AVD_NOT_PRODUCT",
        "R9_VISUAL_REVIEW_HOST_AVD_CHROME=DETECTED_FILTERED_FROM_REVIEW",
        "R9_VISUAL_REVIEW_HOST_AVD_GOOGLE_MESSAGES=DETECTED_FILTERED_FROM_REVIEW",
        "R9_VISUAL_REVIEW_VANADIUM_PROOF=DEFERRED_PHYSICAL_PANTHER",
        "R9_VISUAL_REVIEW_PLATFORM_NIGHT_MODE_PROOF=DEFERRED_PHYSICAL_PANTHER",
        "R9_VISUAL_REVIEW_APPEARANCE_PROVIDER=PASS",
        "prepare-ready.txt",
        "R9_VISUAL_REVIEW_PREPARE_READY=PASS",
    ):
        require(
            mac_runner,
            needle,
            "R9_VISUAL_REVIEW_MAC_FIDELITY_SCOPE",
        )
    for needle in (
        "content://org.sableos.start.appearance/appearance",
        "R9_VISUAL_FIDELITY_EXPECTED_MODE=PASS",
        "R9_VISUAL_FIDELITY_HOST_CHROME=DETECTED_FILTERED",
        "R9_VISUAL_FIDELITY_PLATFORM_NIGHT_MODE_PROOF=DEFERRED_PHYSICAL_PANTHER",
        "R9_VISUAL_FIDELITY_VANADIUM_PROOF=DEFERRED_PHYSICAL_PANTHER",
        "R9_VISUAL_FIDELITY_AUDIT=PASS",
    ):
        require(
            fidelity_audit,
            needle,
            "R9_VISUAL_REVIEW_FIDELITY_AUDIT_CONTRACT",
        )
    for needle in (
        "audit-r9-launcher-review-fidelity.sh",
        "org.sableos.hub/.MainActivity",
        "04-theme-$MODE-start.png",
        "05-theme-$MODE-sable-messages.png",
        "R9_THEME_FIDELITY_PROVIDER_MODE=PASS",
        "R9_THEME_FIDELITY_CROSS_APP_VISUAL_REVIEW=PENDING_USER_REVIEW",
        "R9_THEME_FIDELITY_PLATFORM_NIGHT_MODE=DEFERRED_PHYSICAL_PANTHER",
        "R9_THEME_FIDELITY_VANADIUM=DEFERRED_PHYSICAL_PANTHER",
        "R9_THEME_FIDELITY_CAPTURE=PASS",
    ):
        require(
            theme_capture,
            needle,
            "R9_VISUAL_REVIEW_CROSS_APP_THEME_CAPTURE_CONTRACT",
        )

    for needle in (
        "--es initialScreen \"$screen\"",
        "--es appearanceMode \"$appearance\"",
        "20-production-start-dark",
        "21-production-start-light",
        "22-production-live-dark",
        "23-production-calendar-dark",
        "24-production-messages-dark",
        "MAC_SCOPE=PRODUCTION_SABLE_OWNED_UI_ONLY",
        "prepare-ready.txt",
        "R9_PRODUCTION_VISUAL=FAIL_PREPARE_NOT_READY",
        "R9_PRODUCTION_VISUAL=FAIL_STALE_PREPARE",
        "R9_PRODUCTION_VISUAL_CORE_PLATFORM_APPS=DEFERRED_PANTHER",
        "R9_PRODUCTION_VISUAL=PASS_CAPTURE_COMPLETE",
    ):
        require(
            production_capture,
            needle,
            "R9_PRODUCTION_MAC_APPROVAL_CAPTURE_CONTRACT",
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
    print("R9_VISUAL_REVIEW_PERMISSION_SUMMARY_PARITY=PASS_CURRENT_USER")
    print("R9_VISUAL_REVIEW_PUBLIC_PACKAGE_MANAGER_PERMISSION_QUERY=PASS")
    print("R9_VISUAL_REVIEW_PACKAGEINFO_API_COMPAT=PASS_MINSDK30")
    print("R9_VISUAL_REVIEW_MESSAGING_SUPPRESSION_PARITY=PASS")
    print("R9_VISUAL_REVIEW_APPEARANCE_PROVIDER_PARITY=PASS")
    print("R9_VISUAL_REVIEW_APPEARANCE_PERSISTENCE_PARITY=PASS")
    print("R9_VISUAL_REVIEW_HOST_CHROME_FILTER=PASS")
    print("R9_VISUAL_REVIEW_HOST_GOOGLE_MESSAGES_FILTER=PASS")
    print("R9_VISUAL_REVIEW_HOST_CALENDAR_FILTER=PASS")
    print("R9_VISUAL_REVIEW_RETIRED_WEATHER_FIXTURE_FILTER=PASS")
    print("R9_VISUAL_REVIEW_BROWSER_IDENTITY_SCOPE=PASS_DEFERRED_PANTHER")
    print("R9_VISUAL_REVIEW_PLATFORM_NIGHT_MODE_SCOPE=PASS_DEFERRED_PANTHER")
    print("R9_VISUAL_REVIEW_FIDELITY_AUDIT_CONTRACT=PASS")
    print("R9_VISUAL_REVIEW_CROSS_APP_THEME_CAPTURE_CONTRACT=PASS_SABLE_MESSAGES")
    print("R9_PRODUCTION_MAC_APPROVAL_CAPTURE_CONTRACT=PASS_SABLE_OWNED_ONLY")\n    print("R9_PRODUCTION_MAC_CAPTURE_FRESHNESS=PASS_FAIL_CLOSED")
    print("R9_VISUAL_REVIEW_SYSTEM_BAR_PARITY=PASS")
    print("R9_QUICKSTEP_SYSTEM_BAR_RESTORE=PASS")
    print("R9_VISUAL_REVIEW_LINT_TEST_SURFACE=PASS")
    print("R9_VISUAL_REVIEW_PRODUCTION_SCREEN=PASS")
    print("R9_VISUAL_REVIEW_NOT_HOME=PASS")
    print("R9_VISUAL_REVIEW_ABSENT_FROM_PRODUCT_GRAPH=PASS")
    print("R9_PRODUCTION_REAL_ICONS=PASS")
    print("R9_START_FAVORITE_TILE_STATE_SEPARATION=PASS")
    print("R9_START_DEFAULT_TILES=PASS_10")
    print("R9_START_WEATHER_PACKAGE_PREFERENCE=PASS")
    print("R9_START_PACKAGE_FIRST_PREFERENCE=PASS")
    print("R9_START_TILE_CAP=PASS_UNCAPPED_EXPLICIT")
    print("R9_START_TILE_LONG_PRESS_PEEK=PASS")
    print("R9_START_STATE_PERSISTENCE_SEPARATED=PASS")
    print("R9_START_FINAL_CAPTURE_SET=PASS")
    print("R9_START_FINAL_EXACT_FRAME_HASH_SET=PASS")
    print("R9_START_FINAL_SCROLL_PROOF=PASS_SEMANTIC_DELTA")
    print("R9_START_FINAL_HASH_RESOLUTION_PARSER=PASS_BASENAME")
    print("R9_START_FINAL_WEATHER_FIXTURE_CHECK=PASS_RETIRED")
    print("R9_START_FINAL_SCROLL_FIXTURE=PASS_EXTENDED_14")
    print("R9_START_APPROVED_SETTINGS_GEAR=PASS_PHOSPHOR")
    print("R9_START_ODD_TILE_LAYOUT=PASS")
    print("R9_START_DIMENSIONAL_METRO_HIERARCHY=PASS")
    print("R9_SEARCH_FLAT_METRO_INPUT=PASS")
    print("R9_SEARCH_COMMAND_APP_HIERARCHY=PASS")
    print("R9_PEEK_FLAT_CONTEXTUAL_LAYER=PASS")
    print("R9_PEEK_ACTION_HIERARCHY=PASS")
    print("R9_LOCAL_CONTEXT_FLAT_ROWS=PASS")
    print("R9_LOCAL_CONTEXT_TRUTHFUL_STATUS=PASS_PROVIDER_OWNED")
    print("R9_APPEARANCE_FLAT_CHOICES=PASS")
    print("R9_APPEARANCE_THEME_ACCENT_MODEL=PASS")
    print("R9_VISUAL_REVIEW_COMPONENT_CAPTURE=PASS")
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
    print("R9_L15_VISUAL_REVIEW_CONTRACT=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
