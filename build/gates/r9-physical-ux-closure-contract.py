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
    "PullToRefreshBox(",
    "onRefresh = onRefreshLive",
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
    "resolve_launcher_root",
    '"packages/apps/Launcher3"',
    "R9_QUICKSTEP_RECENTS_ONLY_SOURCE_RESOLUTION_SELF_TEST=PASS",
    "R9_QUICKSTEP_RECENTS_FINAL_SCOPE_SELF_TEST=PASS",
    "R9_QUICKSTEP_STALE_FINAL_IMPORT_REPAIR_SELF_TEST=PASS",
    "R9_QUICKSTEP_RECENTS_STALE_FINAL_UPGRADE=PASS_RESOLVEINFO_IMPORT",
    "upgrade-final",
    "R9_QUICKSTEP_RESOLVEINFO_SECONDARY_HOME_SELF_TEST=PASS",
    "import android.content.pm.ResolveInfo;",
    "ResolveInfo secondaryInfo =",
    "R9_QUICKSTEP_RECENTS_ONLY_LAUNCHER_ROOT=",
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
if (
    ROOT
    / "patches/android-17-grapheneos-2026081300/apply_r9_launcher_cohesion.py"
).exists():
    failures.append("retired_launcher_cohesion_applicator_present")

# Live providers: general sensitive snapshots remain SableLauncher-only.
# Sable Mail additionally admits the bounded first-party SableHub caller for
# the Hub Email pivot; arbitrary apps and Launcher3 remain excluded.
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
    '"org.sableos.launcher"',
    '"org.sableos.hub"',
    "packages.intersect(authorized).isEmpty()",
    "Sable mail snapshot is restricted to SableLauncher and SableHub.",
)
require(
    "apps/r8/mail/verify_sable_mail.py",
    '"org.sableos.launcher"',
    '"org.sableos.hub"',
    "packages.intersect(authorized).isEmpty()",
    "Sable mail snapshot is restricted to SableLauncher and SableHub.",
    "SABLE_MAIL_RETIRED_LAUNCHER3_SNAPSHOT_CALLER=PASS_ABSENT",
    "SABLE_MAIL_HUB_SNAPSHOT_CALLER=PASS_BOUNDED_READ_ONLY",
)
forbid(
    "apps/r8/mail/verify_sable_mail.py",
    """        'if ("com.android.launcher3" !in packages)',
        "SecurityException(",""",
)

# Weather: the hourly list must begin at the provider's current local hour,
# not the first midnight row returned for the forecast day. Successful refresh
# must also invalidate the launcher-facing snapshot URI.
require(
    "apps/r8/rust/crates/weather-core/src/lib.rs",
    'string_for_key(current_object, "time")',
    "local_hour_start(&value)",
    "hourly_start.saturating_add(24)",
    "hourly_start..hourly_end",
    'assert_eq!(snapshot.hourly[0].time, "2026-09-21T09:00")',
)
require(
    "apps/r8/android/weather/src/main/java/org/sableos/weather/WeatherRepository.kt",
    "WeatherSnapshotContract.SNAPSHOT_URI",
    "contentResolver.notifyChange(",
)
require(
    "apps/r8/android/weather/src/main/java/org/sableos/weather/WeatherSnapshotProvider.kt",
    "cursor.setNotificationUri(",
    "WeatherSnapshotContract.SNAPSHOT_URI",
)
require(
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt",
    "destination == SableStartDestination.Live",
    "onRefreshLive()",
    "PullToRefreshBox(",
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
    "R9_PHOTOS_SYSTEM_BARS=PASS_DAY_NIGHT_MATCH_WINDOW",
    'android:windowLightStatusBar">true',
    'android:windowLightNavigationBar">true',
    "R9_CAMERA_PRESENTATION_BOUNDARY=PASS_UPSTREAM_PREPROCESSED_APK",
    "R9_VANADIUM_PRESENTATION_BOUNDARY=PASS_UPSTREAM_SECURITY_BUILD",
)

# Sable-owned Network Manager copy must describe the platform capability
# without presenting the upstream OS as a competing product identity.
require(
    "patches/android-17-grapheneos-2026081300/r9_settings_cohesion/strings_sable_cohesion.xml",
    "Uses the system Network permission.",
    "current platform permission",
)
forbid(
    "patches/android-17-grapheneos-2026081300/r9_settings_cohesion/strings_sable_cohesion.xml",
    "GrapheneOS",
)

# Framework-owned developer notifications are user-visible product shell.
# Keep the underlying android package identity, but substitute the visible
# notification app name with SableOS rather than leaking the upstream OS brand.
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_systemui_coherence.py",
    "core/java/android/debug/AdbNotifications.java",
    "Notification.EXTRA_SUBSTITUTE_APP_NAME",
    '"SableOS"',
    "R9_ADB_NOTIFICATION_PRODUCT_IDENTITY=PASS_SABLEOS",
)

# Hub live status must include active connected-app conversations and both
# Hub and Start expose an explicit pull-to-refresh escape hatch.
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/HubSnapshotProvider.kt",
    "ConnectedNotificationActivityRegistry.activeConversationCount()",
    '0 -> "0 active"',
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/ConnectedNotificationHistoryStore.kt",
    "HubSnapshotProvider.SNAPSHOT_URI",
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/ui/HubScreen.kt",
    "PullToRefreshBox(",
    "isRefreshing = isRefreshing",
    "onRefresh = onRefresh",
)

# Hub notification adapters must suppress group summaries/non-conversation
# notifications, normalize self-authored MessagingStyle messages and keep the
# latest root/thread content immediately visible.
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/notifications/SableNotificationListenerService.kt",
    "Notification.FLAG_GROUP_SUMMARY",
    "Notification.CATEGORY_MESSAGE",
    "Notification.EXTRA_MESSAGING_PERSON",
    "isConversationCandidate()",
    "samePerson(",
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/HubModels.kt",
    "deduplicateRecords(",
    "LOCAL_REPLY_DEDUP_WINDOW_MILLIS",
    "identity = identity",
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/ConnectedNotificationHistoryStore.kt",
    "DATABASE_VERSION = 2",
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/ui/HubScreen.kt",
    "reverseLayout = true",
    "messages.asReversed()",
    "newestConversation?.lastDateMillis",
    "listState.scrollToItem(0)",
)

# Messages People uses the already sorted local ContactsProvider snapshot and
# a bounded lazy-list alphabet rail; it does not introduce a second contact DB.
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/ui/HubScreen.kt",
    "PeopleAlphabetRail(",
    "buildPeopleAlphabetTargets(",
    "rememberLazyListState()",
    "listState.scrollToItem(position)",
)

# Text Reader is a standalone offline-first product surface.
require(
    "apps/r8/textreader/apply_sable_flavor.py",
    'applicationId = "org.sableos.textreader"',
    "SableGlobalTheme(window = window)",
    "SABLE_TEXT_READER_INTERNET_MERGE_RULE=PASS_REMOVE",
    "SABLE_TEXT_READER_INTERNET_PERMISSION=PASS_FINAL_APK_ABSENT_REQUIRED",
    "SABLE_TEXT_READER_TRANSLATION=PASS_RETIRED",
    "SABLE_TEXT_READER_VIEW_SEND_PROCESS_TEXT=PASS",
    "SABLE_TEXT_READER_OCR=PASS_CAMERA_GALLERY_LATIN_DEVANAGARI",
    "SABLE_TEXT_READER_VIEW_HANDLER=PASS_BOUNDED_LOCAL_TEXT",
    "SABLE_TEXT_READER_TEXT_INPUT=PASS_BOUNDED_2_MIB",
    "SABLE_TEXT_READER_TTS_NETWORK_VOICES=PASS_FILTERED",
)
require(
    "apps/r8/textreader/verify_sable_textreader.py",
    'forbid(build, "com.google.mlkit:translate", "SABLE_TEXT_READER_TRANSLATION_DEPENDENCY")',
    'forbid(shared, "downloadModelIfNeeded", "SABLE_TEXT_READER_MODEL_FETCH")',
    "SABLE_TEXT_READER_SINGLE_LAUNCHER=PASS",
    "SABLE_TEXT_READER_TEXT_INPUT=PASS_BOUNDED_2_MIB",
    "SABLE_TEXT_READER_TTS_NETWORK_VOICES=PASS_FILTERED",
    "SABLE_TEXT_READER_APK_OFFLINE_BOUNDARY=PASS",
    "SABLE_TEXT_READER_POLICY=PASS",
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
    "SABLE_READER_IN_APP_PRODUCT_IDENTITY=PASS_SABLE_READER",
    "SABLE_READER_ABOUT_IDENTITY=PASS_SABLE_READER_WITH_UPSTREAM_ATTRIBUTION",
    'if (BuildConfig.SABLE_PRODUCT) "Sable Reader" else "Vaachak"',
    "SABLE_READER_TEXTREADER_COMPOSITION=PASS_ABSENT",
    "SABLE_READER_PUBLICATION_FOCUS=PASS",
)
forbid(
    "apps/r8/reader/apply_sable_flavor.py",
    "SableTextActivity",
    "SableOcrActivity",
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
    "classify_text_state",
    "inspect_repo_state",
    "R9_CONTACTS_PRESENTATION_PARTIAL_SCOPE=",
    "R9_CONTACTS_PRESENTATION_PARTIAL_CONVERGENCE=PASS",
    "R9_PHONE_CONTACTS_PARTIAL_CONVERGENCE_SELF_TEST=PASS",
    "R9_PHONE_CONTACTS_CONTAINMENT_AWARE_VERIFY_SELF_TEST=PASS",
    "R9_CONTACTS_BEHAVIORAL_SCOPE=PASS_ALPHABET_RAIL_ONLY",
    "R9_CONTACTS_ALPHABET_RAIL=PASS_EXISTING_SECTION_INDEXER",
    "R9_PHONE_CONTACTS_ALPHABET_RAIL=PASS_EXISTING_ADDRESS_BOOK_INDEX",
    "getPositionForHeader",
    "R9_PHONE_BEHAVIORAL_SCOPE=PASS_CONTACTS_ALPHABET_RAIL_ONLY",
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
    "build/panther/build-r8-final-ui.sh",
    "framework-minus-apex",
    "R9_FRAMEWORK_ADB_NOTIFICATION_MODULE_BUILD=PASS",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_settings_cohesion.py",
    "classify_dirty_scope_from_expected",
    '"PRE_COHESION"',
    '"FINAL_COHESION"',
    "R9_SETTINGS_COHESION_UPGRADE_IN_PLACE=AUTHORIZED_BOUNDED_FINAL_SCOPE",
    "R9_SETTINGS_COHESION_SELF_TEST_DRIFT_REJECTION=PASS",
)

require(
    "build/panther/prepare-r8-final-ui.sh",
    "R9_SABLELAUNCHER_STANDALONE_SYNC=PASS",
    'upgrade-final',
    "R9_QUICKSTEP_RECENTS_ONLY=UPGRADED_FINAL",
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
print("R9_MAIL_LIVE_PROVIDER_CALLER_BOUNDARY=PASS_SABLELAUNCHER_AND_SABLEHUB")
print("R9_HUB_CONNECTED_LIVE_STATUS=PASS_ACTIVE_CONVERSATION_AWARE")
print("R9_HUB_CONVERSATION_FILTER=PASS_NO_GROUP_SUMMARY_OR_STATUS_NOISE")
print("R9_HUB_CONVERSATION_DEDUP=PASS")
print("R9_HUB_LATEST_MESSAGE_VISIBILITY=PASS_ROOT_AND_THREAD")
print("R9_SABLE_REFRESH_GESTURES=PASS_START_HUB_AND_LIVE")
print("R9_WEATHER_HOURLY_FRESHNESS=PASS_CURRENT_LOCAL_HOUR")
print("R9_WEATHER_LIVE_SNAPSHOT_INVALIDATION=PASS")
print("R9_LIVE_SURFACE_ENTRY_REFRESH=PASS")
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
