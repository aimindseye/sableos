#!/usr/bin/env python3
"""R9 physical-UX pre-full-build source closure.

This gate does not claim physical acceptance. It verifies that the exact source
prepared for Panther contains the mechanisms needed to retest every physical
regression observed on the rejected Launcher3-hosted candidates.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
failures: list[str] = []


def read(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        failures.append(f"missing_file={rel}")
        return ""
    return path.read_text(encoding="utf-8")


def require(rel: str, *tokens: str) -> None:
    value = read(rel)
    for token in tokens:
        if token not in value:
            failures.append(f"missing_token={rel}:{token}")


def forbid(rel: str, *tokens: str) -> None:
    value = read(rel)
    for token in tokens:
        if token in value:
            failures.append(f"forbidden_token={rel}:{token}")


# Standalone HOME and app inventory / privacy summaries.
require(
    "src/android/packages/apps/SableStart/Android.bp",
    'name: "SableLauncher"',
    ":sable_start_presentation_srcs",
    ":sable_design_shared_srcs",
    'sdk_version: "system_current"',
)
forbid(
    "src/android/packages/apps/SableStart/Android.bp",
    "platform_apis: true",
)

require(
    "src/android/packages/apps/SableStart/AndroidManifest.xml",
    'package="org.sableos.launcher"',
    "android.intent.category.HOME",
)
require(
    "src/android/packages/apps/SableStart/src/com/sable/start/platform/LauncherAppsRepository.kt",
    "PackageManager.GET_PERMISSIONS",
    'Suppress("DEPRECATION")',
    "PackageInfo.REQUESTED_PERMISSION_GRANTED",
    "createContextAsUser(user, 0)",
    'getOrNull() ?: return "permissions · unavailable"',
    "buildPrivacyPermissionSummary(",
    "packageInfo.requestedPermissionsFlags ?: IntArray(0)",
    '"permissions · none sensitive"',
    '"permissions · " + labels.joinToString(" · ")',
    'PrivacyPermissionGroup("camera"',
    'PrivacyPermissionGroup("microphone"',
)
forbid(
    "src/android/packages/apps/SableStart/src/com/sable/start/platform/LauncherAppsRepository.kt",
    "PackageInfoFlags.of(",
)

require(
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt",
    "private fun AppsScreen(",
    "buildRailRows(apps)",
    "rememberLazyListState()",
    "detectDragGestures(",
    "text = app.privacySummary",
)
forbid(
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt",
    "text = app.component.packageName",
    "text = app.component.flattenToString()",
    "text = app.component.flattenToShortString()",
)

# HOME/back lifecycle belongs to the standalone Activity, not Quickstep.
require(
    "src/android/packages/apps/SableStart/src/com/sable/start/SableStartActivity.kt",
    "class SableStartActivity : ComponentActivity()",
    "onBackPressedDispatcher.addCallback(",
    "if (canNavigateBack)",
    "backGeneration.value += 1",
    "if (intent.action == Intent.ACTION_MAIN)",
    "homeGeneration.value += 1",
    "LiveSurfaceRepository.OBSERVED_URIS.forEach",
    "contentResolver.registerContentObserver(",
    "contentResolver.unregisterContentObserver(",
)
forbid(
    "src/android/packages/apps/SableStart/src/com/sable/start/SableStartActivity.kt",
    "QuickstepLauncher",
)

# Quickstep/Recents is retained, but native Launcher3 HOME is removed.
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_quickstep_recents_only.py",
    "R9_QUICKSTEP_RECENTS_ONLY_SELF_TEST=PASS",
    "host.unlink()",
    'android:exported="false"',
    "R9_LAUNCHER3_HOME_ELIGIBILITY=PASS_ABSENT",
    "R9_QUICKSTEP_SERVICE=PASS_RETAINED",
    "R9_FALLBACK_RECENTS=PASS_RETAINED",
)
forbid(
    "build/panther/prepare-r8-final-ui.sh",
    "apply_r9_launcher_cohesion.py",
    "SableQuickstepLauncher",
)

# Live providers: sensitive data is visible only to SableLauncher.
require(
    "apps/r8/android/weather/src/main/java/org/sableos/weather/WeatherSnapshotProvider.kt",
    'packageName == "org.sableos.launcher"',
)
for provider in (
    "apps/r8/android/calendar/src/main/java/org/sableos/calendar/CalendarSnapshotProvider.kt",
    "apps/r8/android/hub/src/main/java/org/sableos/hub/HubSnapshotProvider.kt",
    "apps/r8/android/media/src/main/java/org/sableos/media/MediaSnapshotProvider.kt",
):
    require(
        provider,
        'if ("org.sableos.launcher" !in packages)',
        "SecurityException(",
    )
require(
    "apps/r8/mail/apply_sable_flavor.py",
    'if ("org.sableos.launcher" !in packages)',
)

# Clock/Photos: physical Dark -> Light regression must be structurally fixed.
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_daily_driver_core_presentation.py",
    '<style name="Theme.DeskClock" parent="Theme.AppCompat.DayNight.NoActionBar">',
    "?android:attr/textColorPrimary",
    "?android:attr/textColorSecondary",
    "R9_CLOCK_DAY_NIGHT_PRESENTATION=PASS_SEMANTIC_TEXT_AND_BACKGROUND",
    '<style name="Theme.GalleryBase" parent="android:Theme.Holo.Light">',
    "apply_gallery_night_styles(",
    "verify_gallery_night_styles(",
    "R9_PHOTOS_DAY_NIGHT_PRESENTATION=PASS_LIGHT_BASE_DARK_NIGHT_THEME",
    "R9_CAMERA_PRESENTATION_BOUNDARY=PASS_UPSTREAM_PREPROCESSED_APK",
    "R9_VANADIUM_PRESENTATION_BOUNDARY=PASS_UPSTREAM_SECURITY_BUILD",
)

# Reader: SableOS owns ordinary Light/Dark, Sepia/E-Ink remain explicit reader
# modes, Offline Mode cannot force a white surface, and all actual books are
# rendered continuously instead of being collapsed into six visible stacks.
require(
    "apps/r8/reader/apply_sable_flavor.py",
    "if (!BuildConfig.SABLE_PRODUCT || themeMode == ThemeMode.E_INK)",
    "appearance = rememberGlobalSableAppearance()",
    "theme = if (sableDark) Theme.DARK else Theme.LIGHT",
    "epubPreferences.theme == Theme.SEPIA",
    "R9_READER_LIGHT_DARK_OWNERSHIP=PASS_SABLEOS_GLOBAL",
    "R9_READER_SETTINGS_GLOBAL_APPEARANCE=PASS_NO_OFFLINE_LIGHT_OVERRIDE",
    "R9_READER_LOCAL_LIGHT_DARK_CONTROLS=PASS_RETIRED_FOR_SABLE",
    "state.isOfflineMode && !BuildConfig.SABLE_PRODUCT",
    "SableContinuousLibraryGrid(",
    "LazyVerticalGrid(",
    "distinctBy { it.bookHash }",
    "R9_READER_LIBRARY_COUNT=PASS_ACTUAL_BOOKS_NOT_STACKS",
)

# Contacts uses its existing SectionIndexer, not a duplicate data model.
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_phone_contacts_presentation.py",
    'CONTACTS_INDEXER_ADAPTER = Path(',
    '"src/com/android/contacts/list/IndexerListAdapter.java"',
    "return mIndexer.getPositionForSection(sectionIndex);",
    "getListPositionForSection",
    "getPositionForSection(sectionIndex)",
    "installSableAlphabetRail",
    "scrollToSableSection",
    "R9_CONTACTS_BEHAVIORAL_SCOPE=PASS_ALPHABET_RAIL_ONLY",
    "R9_CONTACTS_ALPHABET_RAIL=PASS_EXISTING_SECTION_INDEXER",
    "R9_CONTACTS_DATA_MODEL_MUTATION=NONE",
)
forbid(
    "patches/android-17-grapheneos-2026081300/apply_r9_phone_contacts_presentation.py",
    "class ContactsSectionIndexer",
    "new ContactsSectionIndexer",
)

# Media uses lazy large-library surfaces, a background immutable index and a
# discoverable A-Z rail. Physical ANR remediation also forbids full-library
# Binder queue payloads and always-on progress recomposition.
require(
    "apps/r8/android/media/src/main/java/org/sableos/media/MediaScreen.kt",
    "private fun MediaAlphabetRail(",
    "buildMediaSectionTargets(",
    "produceState<MediaCollectionIndex?>",
    "withContext(Dispatchers.Default)",
    "buildMediaCollectionIndex(",
    "LibraryPivot.Songs to",
    "LibraryPivot.Artists to",
    "LibraryPivot.Albums to",
    "LibraryPivot.Favorites to",
    "LibraryPivot.Playlists to emptyList()",
    "count = songs.size",
    "count = artistGroups.size",
    "count = albumGroups.size",
    "HorizontalDivider(",
    'text = if (favorite) "★" else "☆"',
    'text = "▶"',
)
forbid(
    "apps/r8/android/media/src/main/java/org/sableos/media/MediaScreen.kt",
    'text = "×"',
    "playback.queue.count { item ->",
)
require(
    "apps/r8/android/media/src/main/java/org/sableos/media/MediaC2Screens.kt",
    "internal fun QueueScreen(",
    "count = upcomingCount",
    "internal fun PlaylistEditorScreen(",
    "items = localItems",
)
forbid(
    "apps/r8/android/media/src/main/java/org/sableos/media/MediaC2Screens.kt",
    "upcomingItems.forEachIndexed",
    "localItems.forEach { item ->",
)
require(
    "apps/r8/android/media/src/main/java/org/sableos/media/MediaApp.kt",
    "LaunchedEffect(localAudioRepository, libraryStateRepository)",
    "playbackController.setProgressUpdatesEnabled(",
    "destination == MediaDestination.NowPlaying",
)
require(
    "apps/r8/android/media/src/main/java/org/sableos/media/PlaybackController.kt",
    "progressUpdatesEnabled",
    "fun setProgressUpdatesEnabled(enabled: Boolean)",
)
require(
    "apps/r8/android/media/src/main/java/org/sableos/media/MainActivity.kt",
    "PlaybackQueueRequestStore.publish(",
    "PlaybackService.EXTRA_QUEUE_TOKEN",
)
forbid(
    "apps/r8/android/media/src/main/java/org/sableos/media/MainActivity.kt",
    "putStringArrayListExtra",
)
require(
    "apps/r8/android/media/src/main/java/org/sableos/media/PlaybackService.kt",
    "PlaybackQueueRequestStore::consume",
    "serviceScope.launch",
    "mainHandler.post",
)

# Build/product closure.
require(
    "product/r8/panther/r8-product.mk",
    "SableLauncher",
)
require(
    "build/panther/sync-sablestart.sh",
    "SABLESTART_STANDALONE_SYNC=PASS",
    "SABLESTART_STANDALONE_RUNTIME=PASS_PRESENT",
)
require(
    "build/panther/prepare-r8-final-ui.sh",
    "R9_SABLELAUNCHER_STANDALONE_SYNC=PASS",
    "R9_QUICKSTEP_RECENTS_ONLY=APPLIED",
    "R9_LAUNCHER3_HOME_ELIGIBILITY=PASS_ABSENT",
)
require(
    "build/panther/build-r8-final-ui.sh",
    "SableLauncher Launcher3QuickStep",
    "R9_SABLELAUNCHER_MODULE_BUILD=PASS",
    "R9_QUICKSTEP_RECENTS_MODULE_BUILD=PASS",
    "R9_SABLE_HOME_QUICKSTEP_PREFLIGHT=PASS",
    "FULL_TARGET_FILES_BUILD",
)
require(
    "build/gates/r8-final-target-files.sh",
    "R9_SABLELAUNCHER_HOME_TARGET_FILES=PASS_PRESENT",
    "R9_LAUNCHER3_RECENTS_TARGET_FILES=PASS_PRESENT",
    "R9_LEGACY_SABLESTART_TARGET_FILES=PASS_ABSENT",
)

# Physical acceptance has separate objective and human checks for every launcher
# failure mode seen in the videos.
require(
    "tests/launcher3/device/r9_home_acceptance.sh",
    'EXPECTED_PACKAGE="org.sableos.launcher"',
    "HOME_RESOLVER",
    "HOME_ROLE_HOLDER",
    "LAUNCHER3_HOME_ROLE_ABSENT",
    "LAUNCHER3_HOME_ELIGIBILITY_ABSENT",
    "QUICKSTEP_SERVICE_PRESENT",
    "SABLE_SUBSURFACE_BACK_GESTURES",
    "SABLE_ABORTED_SWIPE_NO_NATIVE_ESCAPE",
    "SABLE_FALLBACK_RECENTS_GESTURE",
    "SABLE_STATUS_SHADE_GESTURE_STABILITY",
    "R9_SABLE_HOME_DEVICE_ACCEPTANCE",
)

# Canonical qualification sequence must remain module-only before authorizing a
# fresh target-files build.
require(
    "build/panther/qualify-r9-physical-ux.sh",
    "BUILD_AUTHORIZED=YES_MODULES_ONLY",
    "FULL_TARGET_FILES_BUILD_AUTHORIZED=NO",
    "R9_PHYSICAL_UX_MODULE_QUALIFICATION=PASS",
    "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES_AFTER_MODULE_QUALIFICATION",
)

# Run pure self-tests from this source contract. They do not mutate Android
# workspace or contact a device.
self_tests = (
    (
        "R9_QUICKSTEP_RECENTS_ONLY_SELF_TEST=PASS",
        ROOT
        / "patches/android-17-grapheneos-2026081300"
        / "apply_r9_quickstep_recents_only.py",
    ),
    (
        "R9_PHONE_CONTACTS_PRESENTATION_SELF_TEST=PASS",
        ROOT
        / "patches/android-17-grapheneos-2026081300"
        / "apply_r9_phone_contacts_presentation.py",
    ),
)

for marker, script in self_tests:
    result = subprocess.run(
        ["python3", str(script), "--self-test"],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0 or marker not in result.stdout:
        failures.append(
            f"self_test_failed={script.name}:rc={result.returncode}:"
            f"stdout={result.stdout!r}:stderr={result.stderr!r}"
        )

if failures:
    print("R9_PHYSICAL_UX_CLOSURE_CONTRACT=FAIL")
    for failure in failures:
        print(f"FAILURE={failure}")
    raise SystemExit(1)

print("R9_SABLE_HOME_SOURCE=PASS_STANDALONE")
print("R9_QUICKSTEP_RECENTS_SOURCE=PASS_NO_HOME")
print("R9_ALL_APPS_PERMISSION_SUMMARY_CONTRACT=PASS")
print("R9_LIVE_PROVIDER_CALLER_BOUNDARY=PASS_SABLELAUNCHER")
print("R9_CLOCK_LIGHT_VISIBILITY_CONTRACT=PASS")
print("R9_PHOTOS_LIGHT_DARK_CONTRACT=PASS")
print("R9_CAMERA_APPEARANCE_BOUNDARY=PASS_UPSTREAM_DARK_ONLY")
print("R9_READER_GLOBAL_APPEARANCE_CONTRACT=PASS")
print("R9_READER_ACTUAL_BOOK_COUNT_CONTRACT=PASS")
print("R9_CONTACTS_ALPHABET_RAIL_CONTRACT=PASS")
print("R9_MEDIA_ALPHABET_RAIL_CONTRACT=PASS")
print("R9_MEDIA_FLAT_ROWS_CONTRACT=PASS")
print("R9_MEDIA_LARGE_LIBRARY_RENDER_CONTRACT=PASS")
print("R9_MEDIA_LARGE_LIBRARY_INDEX_CONTRACT=PASS_OFF_MAIN")
print("R9_MEDIA_QUEUE_HANDOFF_CONTRACT=PASS_TOKEN_ONLY")
print("R9_MEDIA_PROGRESS_RECOMPOSITION_CONTRACT=PASS_NOW_PLAYING_ONLY")
print("R9_CANONICAL_PRE_FULL_QUALIFICATION=PASS")
print("R9_PHYSICAL_UX_CLOSURE_CONTRACT=PASS")
