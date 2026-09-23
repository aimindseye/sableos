#!/usr/bin/env python3
"""R9 current system-cohesion source contract.

This gate intentionally describes the *current* Panther architecture after the
physical rejection of Sable-over-Launcher3. It is repository-only: no Android
workspace mutation, build, device contact, reboot, flash, or wipe occurs here.

R9 architecture:
- Settings owns the persisted global Sable appearance authority.
- org.sableos.launcher / SableLauncher owns user-facing HOME.
- Launcher3QuickStep is retained only as Android Quickstep/Recents substrate.
- Sable-owned live snapshot providers admit SableLauncher, not Launcher3.
- GrapheneOS Messaging remains the default SMS/MMS transport substrate while
  Sable Messages is the visible SMS/People surface.
- Embedded third-party provider WebViews are retired; optional social services
  are ordinary installed apps / future notification adapters.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
failures: list[str] = []


def text(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        failures.append(f"missing_file={rel}")
        return ""
    return path.read_text(encoding="utf-8")


def require(rel: str, *needles: str) -> None:
    value = text(rel)
    for needle in needles:
        if needle not in value:
            failures.append(f"missing_token={rel}:{needle}")


def forbid(rel: str, *needles: str) -> None:
    value = text(rel)
    for needle in needles:
        if needle in value:
            failures.append(f"forbidden_token={rel}:{needle}")


# ---------------------------------------------------------------------------
# Architecture record.
# ---------------------------------------------------------------------------
require(
    "docs/R9_SABLE_HOME_REPLACEMENT.md",
    "SableLauncher",
    "package: org.sableos.launcher",
    "Launcher3QuickStep remains installed for R9 only as the Android",
    "R9_LAUNCHER3_HOME_ROLE=PASS_ABSENT",
    "Keyboard-first contract",
    "Contacts alphabet rail",
    "Media library navigation",
)

# ---------------------------------------------------------------------------
# Global appearance authority: Settings persists and restores it; SableLauncher
# is a client/editor, never a second authority.
# ---------------------------------------------------------------------------
require(
    "src/android/shared/sabledesign/src/main/java/org/sableos/design/SableGlobalAppearance.kt",
    'const val AUTHORITY = "org.sableos.appearance"',
    "rememberGlobalSableAppearance",
    "writeGlobalSableAppearance(",
    "registerContentObserver",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_settings_cohesion.py",
    "SableAppearanceProvider.java",
    "SableAppearanceBootReceiver.java",
    "SableAppearanceSettings.java",
    "SableNetworkManagerSettings.java",
    "R9_SETTINGS_NETWORK_MANAGER=PASS_GRAPHENE_NETWORK_PERMISSION",
    "classify_dirty_scope_from_expected",
    '"PRE_COHESION"',
    '"FINAL_COHESION"',
    "R9_SETTINGS_COHESION_UPGRADE_IN_PLACE=AUTHORIZED_BOUNDED_FINAL_SCOPE",
    "R9_SETTINGS_COHESION_UPGRADE_IN_PLACE=PASS",
    "R9_SETTINGS_COHESION_SELF_TEST_DRIFT_REJECTION=PASS",
)
require(
    "patches/android-17-grapheneos-2026081300/r9_settings_cohesion/strings_sable_cohesion.xml",
    "Uses the system Network permission.",
    "current platform permission",
)
forbid(
    "patches/android-17-grapheneos-2026081300/r9_settings_cohesion/strings_sable_cohesion.xml",
    "GrapheneOS",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_systemui_coherence.py",
    "core/java/android/debug/AdbNotifications.java",
    "Notification.EXTRA_SUBSTITUTE_APP_NAME",
    '"SableOS"',
    "R9_ADB_NOTIFICATION_PRODUCT_IDENTITY=PASS_SABLEOS",
    "R9_ADB_NOTIFICATION_PRODUCT_IDENTITY_SELF_TEST=PASS",
)
require(
    "patches/android-17-grapheneos-2026081300/r9_settings_cohesion/SableAppearanceContract.java",
    'AUTHORITY = "org.sableos.appearance"',
    'Uri.parse("content://" + AUTHORITY + "/" + PATH_APPEARANCE)',
)
require(
    "patches/android-17-grapheneos-2026081300/r9_settings_cohesion/SableAppearanceProvider.java",
    "SableAppearanceContract.CONTENT_URI",
    'Arrays.asList(packages).contains("org.sableos.launcher")',
    "Sable appearance writes are restricted to Settings and SableLauncher",
)
forbid(
    "patches/android-17-grapheneos-2026081300/r9_settings_cohesion/SableAppearanceProvider.java",
    'Arrays.asList(packages).contains("com.android.launcher3")',
)
forbid(
    "src/android/packages/apps/SableStart/src/com/sable/start/platform/StartStateRepository.kt",
    "loadAppearance(",
    "saveAppearance(",
    "KEY_SYSTEM_NIGHT_MODE_BEFORE_OVERRIDE",
)
if (ROOT / "src/android/packages/apps/SableStart/src/com/sable/start/platform/SableAppearanceProvider.kt").exists():
    failures.append("retired_launcher_local_appearance_provider_present")

# ---------------------------------------------------------------------------
# Standalone Sable HOME.
# ---------------------------------------------------------------------------
require(
    "src/android/packages/apps/SableStart/Android.bp",
    'name: "sable_start_presentation_srcs"',
    'name: "SableLauncher"',
    'manifest: "AndroidManifest.xml"',
    'certificate: "platform"',
    'sdk_version: "system_current"',
    "LauncherAppsRepository.kt",
    "SableStartActivity.kt",
)
forbid(
    "src/android/packages/apps/SableStart/Android.bp",
    "platform_apis: true",
)

require(
    "src/android/packages/apps/SableStart/AndroidManifest.xml",
    'package="org.sableos.launcher"',
    'android:name="org.sableos.start.SableStartActivity"',
    "android.intent.action.MAIN",
    "android.intent.category.HOME",
    "android.intent.category.DEFAULT",
    'android:excludeFromRecents="true"',
    'android:launchMode="singleTask"',
    'android:authorities="org.sableos.appearance"',
    'android:authorities="org.sableos.weather.snapshot"',
    'android:authorities="org.sableos.calendar.snapshot"',
    'android:authorities="org.sableos.hub.snapshot"',
    'android:authorities="org.sableos.mail.snapshot"',
    'android:authorities="org.sableos.media.snapshot"',
)
require(
    "src/android/packages/apps/SableStart/src/com/sable/start/SableStartActivity.kt",
    "class SableStartActivity : ComponentActivity()",
    "LauncherAppsRepository(this)",
    "rememberGlobalSableAppearance()",
    "writeGlobalSableAppearance(",
    "onBackPressedDispatcher.addCallback(",
    "homeGeneration.value += 1",
    "backGeneration.value += 1",
    "LiveSurfaceRepository.OBSERVED_URIS.forEach",
    "contentResolver.registerContentObserver(",
)
forbid(
    "src/android/packages/apps/SableStart/src/com/sable/start/SableStartActivity.kt",
    "QuickstepLauncher",
    "LauncherState",
    "RecentsView",
)
require(
    "src/android/packages/apps/SableStart/src/com/sable/start/platform/LauncherAppsRepository.kt",
    "LauncherApps::class.java",
    "getActivityList(null, user)",
    "startMainActivity(",
    "startAppDetailsActivity(",
    "PackageManager.GET_PERMISSIONS",
    'Suppress("DEPRECATION")',
    "PackageInfo.REQUESTED_PERMISSION_GRANTED",
    "createContextAsUser(user, 0)",
    'getOrNull() ?: return "permissions · unavailable"',
    'GRAPHENE_MESSAGING_PACKAGE = "com.android.messaging"',
    '"permissions · none sensitive"',
)
forbid(
    "src/android/packages/apps/SableStart/src/com/sable/start/platform/LauncherAppsRepository.kt",
    "PackageInfoFlags.of(",
)

require(
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt",
    "private fun AppsScreen(",
    "private fun SearchScreen(",
    "SableStartDestination.Peek",
    "text = app.privacySummary",
    "rememberLazyListState()",
    "buildRailRows(apps)",
)

# ---------------------------------------------------------------------------
# Messages: native-first Sable presentation over retained mature SMS/MMS
# transport. No embedded provider web sessions belong in the Messages product.
# ---------------------------------------------------------------------------
require(
    "apps/r8/android/hub/src/main/AndroidManifest.xml",
    'android.permission.READ_SMS',
    'android.permission.SEND_SMS',
    'android.permission.READ_CONTACTS',
    'android:name=".MainActivity"',
)
forbid(
    "apps/r8/android/hub/src/main/AndroidManifest.xml",
    'android.permission.INTERNET',
    '.web.',
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/MainActivity.kt",
    "withContext(Dispatchers.IO)",
    "repository.snapshot()",
    "SableGlobalTheme(window = window)",
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/ui/HubScreen.kt",
    "HubPivot.Messages",
    "HubPivot.People",
    'label = { Text("Search conversations") }',
    'text = "MMS / attachment"',
    "MessageBubble(",
)
forbid(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/ui/HubScreen.kt",
    "HubPivot.Services",
    "ProviderCapabilityClass",
    "Private web session",
    "private, isolated web sessions",
    "RCS",
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/HubRepository.kt",
    "RoleManager.ROLE_SMS",
    "openAndroidMessaging(",
)
forbid(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/MainActivity.kt",
    "createRequestRoleIntent",
    "ProviderCapsuleLauncher",
)
if (
    ROOT
    / "apps/r8/android/hub/src/main/java/org/sableos/hub/web/ProviderCapsuleActivity.kt"
).exists():
    failures.append("retired_sable_messages_provider_capsule_present")

# ---------------------------------------------------------------------------
# Quickstep is recents-only, not a Sable host and not a HOME candidate.
# ---------------------------------------------------------------------------
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_quickstep_recents_only.py",
    'LAUNCHER3_HEAD = "e5fde8f4368539554b07ee136abd27bc7b4284c1"',
    "restore_pinned_scope(",
    "host.unlink()",
    'android:exported="false"',
    "new ComponentName(context, QuickstepLauncher.class)",
    "Private QuickstepLauncher activity missing",
    "android.intent.action.QUICKSTEP_SERVICE",
    "com.android.quickstep.TouchInteractionService",
    "com.android.quickstep.RecentsActivity",
    "R9_SABLE_LAUNCHER3_HOST=PASS_ABSENT",
    "R9_LAUNCHER3_HOME_ELIGIBILITY=PASS_ABSENT",
    "R9_QUICKSTEP_SERVICE=PASS_RETAINED",
    "R9_FALLBACK_RECENTS=PASS_RETAINED",
    "R9_QUICKSTEP_RECENTS_ONLY=PASS",
    "R9_QUICKSTEP_RECENTS_ONLY_SELF_TEST=PASS",
)
require(
    "build/panther/prepare-r8-final-ui.sh",
    'QUICKSTEP_RECENTS_ONLY="$ROOT/patches/android-17-grapheneos-2026081300/apply_r9_quickstep_recents_only.py"',
    "===== STANDALONE SABLE HOME SYNC =====",
    "R9_SABLELAUNCHER_STANDALONE_SYNC=PASS",
    "===== QUICKSTEP RECENTS-ONLY SUBSTRATE =====",
    'python3 "$QUICKSTEP_RECENTS_ONLY" --source "$WS" apply',
    'python3 "$QUICKSTEP_RECENTS_ONLY" --source "$WS" verify',
    "R9_SABLELAUNCHER_HOME_OWNERSHIP=PASS_SOURCE",
    "R9_LAUNCHER3_HOME_ELIGIBILITY=PASS_ABSENT",
)
forbid(
    "build/panther/prepare-r8-final-ui.sh",
    "LAUNCHER_COHERENCE=",
    'python3 "$LAUNCHER_COHERENCE"',
    "SableQuickstepLauncher",
)

# ---------------------------------------------------------------------------
# Product and target-files ownership.
# ---------------------------------------------------------------------------
require(
    "product/r8/panther/r8-product.mk",
    "SableLauncher",
    "SableMedia",
    "SableTextReader",
    "SableReader",
    "SableHub",
    "SableMail",
    "SableWeather",
    "SableCalendar",
)
require(
    "build/gates/r8-final-target-files.sh",
    'matches("SableLauncher.apk")',
    "[SableLauncher.apk]=org.sableos.launcher",
    "R9_SABLELAUNCHER_HOME_TARGET_FILES=PASS_PRESENT",
    "R9_LAUNCHER3_RECENTS_TARGET_FILES=PASS_PRESENT",
    "R9_LEGACY_SABLESTART_TARGET_FILES=PASS_ABSENT",
    "[SableTextReader.apk]=org.sableos.textreader",
    "R9_SABLE_TEXT_READER_TARGET_FILES=PASS_PRESENT",
)
require(
    "build/gates/r8-no-stale-product-code.sh",
    "R9_STANDALONE_SABLELAUNCHER_PRODUCT_MODULE=PASS",
    "R9_SABLE_TEXT_READER_PRODUCT_MODULE=PASS",
)

# ---------------------------------------------------------------------------
# Live snapshot privacy boundary moves from Launcher3 to SableLauncher.
# ---------------------------------------------------------------------------
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
        "Binder.getCallingUid()",
        "getPackagesForUid(callingUid)",
        'if ("org.sableos.launcher" !in packages)',
        "SecurityException(",
    )
require(
    "apps/r8/mail/apply_sable_flavor.py",
    "SableMailSnapshotProvider.kt",
    'if ("org.sableos.launcher" !in packages)',
    "Sable live snapshot is restricted to SableLauncher.",
)
forbid(
    "apps/r8/mail/apply_sable_flavor.py",
    'if ("com.android.launcher3" !in packages)',
)
require(
    "apps/r8/mail/verify_sable_mail.py",
    'if ("org.sableos.launcher" !in packages)',
    "Sable live snapshot is restricted to SableLauncher.",
    "SABLE_MAIL_RETIRED_LAUNCHER3_SNAPSHOT_CALLER=PASS_ABSENT",
)
forbid(
    "apps/r8/mail/verify_sable_mail.py",
    """        'if ("com.android.launcher3" !in packages)',
        "SecurityException(",""",
)

# ---------------------------------------------------------------------------
# User-observed physical regressions: source contracts.
# ---------------------------------------------------------------------------
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_daily_driver_core_presentation.py",
    "Theme.AppCompat.DayNight.NoActionBar",
    "?android:attr/textColorPrimary",
    "?android:attr/textColorSecondary",
    "R9_CLOCK_DAY_NIGHT_PRESENTATION=PASS_SEMANTIC_TEXT_AND_BACKGROUND",
    'parent="android:Theme.Holo.Light"',
    "values-night/styles.xml",
    "R9_PHOTOS_DAY_NIGHT_PRESENTATION=PASS_LIGHT_BASE_DARK_NIGHT_THEME",
    "R9_PHOTOS_SYSTEM_BARS=PASS_DAY_NIGHT_MATCH_WINDOW",
    'android:windowLightStatusBar">true',
    'android:windowLightNavigationBar">true',
    "R9_CAMERA_PRESENTATION_BOUNDARY=PASS_UPSTREAM_PREPROCESSED_APK",
)
require(
    "apps/r8/textreader/apply_sable_flavor.py",
    'applicationId = "org.sableos.textreader"',
    "SableGlobalTheme(window = window)",
    "SABLE_TEXT_READER_INTERNET_MERGE_RULE=PASS_REMOVE",
    "SABLE_TEXT_READER_INTERNET_PERMISSION=PASS_FINAL_APK_ABSENT_REQUIRED",
    "SABLE_TEXT_READER_TRANSLATION=PASS_RETIRED",
    "SABLE_TEXT_READER_OCR=PASS_CAMERA_GALLERY_LATIN_DEVANAGARI",
    "SABLE_TEXT_READER_TEXT_INPUT=PASS_BOUNDED_2_MIB",
    "SABLE_TEXT_READER_TTS_NETWORK_VOICES=PASS_FILTERED",
)
require(
    "apps/r8/textreader/verify_sable_textreader.py",
    "SABLE_TEXT_READER_SINGLE_LAUNCHER=PASS",
    "SABLE_TEXT_READER_POLICY=PASS",
)

require(
    "apps/r8/reader/apply_sable_flavor.py",
    "R9_READER_LIGHT_DARK_OWNERSHIP=PASS_SABLEOS_GLOBAL",
    "R9_READER_SETTINGS_GLOBAL_APPEARANCE=PASS_NO_OFFLINE_LIGHT_OVERRIDE",
    "R9_READER_LOCAL_LIGHT_DARK_CONTROLS=PASS_RETIRED_FOR_SABLE",
    "R9_READER_LIBRARY_NAVIGATION=PASS_CONTINUOUS_VERTICAL_GRID",
    "R9_READER_LIBRARY_COUNT=PASS_ACTUAL_BOOKS_NOT_STACKS",
    "SABLE_READER_IN_APP_PRODUCT_IDENTITY=PASS_SABLE_READER",
    "SABLE_READER_ABOUT_IDENTITY=PASS_SABLE_READER_WITH_UPSTREAM_ATTRIBUTION",
    'if (BuildConfig.SABLE_PRODUCT) "Sable Reader" else "Vaachak"',
    "distinctBy { it.bookHash }",
    "state.isOfflineMode && !BuildConfig.SABLE_PRODUCT",
    "Sepia",
    "ThemeMode.E_INK",
    "SABLE_READER_TEXTREADER_COMPOSITION=PASS_ABSENT",
    "SABLE_READER_PUBLICATION_FOCUS=PASS",
)
forbid(
    "apps/r8/reader/apply_sable_flavor.py",
    "SableTextActivity",
    "SableOcrActivity",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_phone_contacts_presentation.py",
    "getListPositionForSection",
    "classify_text_state",
    "inspect_repo_state",
    "R9_CONTACTS_PRESENTATION_PARTIAL_CONVERGENCE=PASS",
    "R9_PHONE_CONTACTS_PARTIAL_CONVERGENCE_SELF_TEST=PASS",
    "R9_PHONE_CONTACTS_CONTAINMENT_AWARE_VERIFY_SELF_TEST=PASS",
    "installSableAlphabetRail",
    "scrollToSableSection",
    "R9_CONTACTS_ALPHABET_RAIL=PASS_EXISTING_SECTION_INDEXER",
    "R9_PHONE_CONTACTS_ALPHABET_RAIL=PASS_EXISTING_ADDRESS_BOOK_INDEX",
    "getPositionForHeader",
    "R9_PHONE_BEHAVIORAL_SCOPE=PASS_CONTACTS_ALPHABET_RAIL_ONLY",
    "R9_CONTACTS_DATA_MODEL_MUTATION=NONE",
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/ui/HubScreen.kt",
    "PeopleAlphabetRail(",
    "buildPeopleAlphabetTargets(",
    "rememberLazyListState()",
    "listState.scrollToItem(position)",
)
require(
    "apps/r8/android/media/src/main/java/org/sableos/media/MediaScreen.kt",
    "private fun MediaAlphabetRail(",
    "buildMediaSectionTargets(",
    "produceState<MediaCollectionIndex?>",
    "withContext(Dispatchers.Default)",
    "LibraryPivot.Songs to",
    "LibraryPivot.Artists to",
    "LibraryPivot.Albums to",
    "LibraryPivot.Favorites to",
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
    "count = upcomingCount",
    "items = localItems",
)
forbid(
    "apps/r8/android/media/src/main/java/org/sableos/media/MediaC2Screens.kt",
    "upcomingItems.forEachIndexed",
    "localItems.forEach { item ->",
)
require(
    "apps/r8/android/media/src/main/java/org/sableos/media/PlaybackController.kt",
    "fun setProgressUpdatesEnabled(enabled: Boolean)",
)
require(
    "apps/r8/android/media/src/main/java/org/sableos/media/PlaybackQueueRequestStore.kt",
    "AtomicReference<PlaybackQueueRequest?>",
)

# ---------------------------------------------------------------------------
# Physical acceptance now proves standalone HOME and fallback Recents.
# ---------------------------------------------------------------------------
require(
    "tests/launcher3/device/r9_home_acceptance.sh",
    'EXPECTED_PACKAGE="org.sableos.launcher"',
    'QUICKSTEP_PACKAGE="com.android.launcher3"',
    "LAUNCHER3_HOME_ROLE_ABSENT",
    "LAUNCHER3_HOME_ELIGIBILITY_ABSENT",
    "QUICKSTEP_SERVICE_PRESENT",
    "QUICKSTEP_FALLBACK_RECENTS_PRESERVED",
    "SABLE_SUBSURFACE_BACK_GESTURES",
    "SABLE_ABORTED_SWIPE_NO_NATIVE_ESCAPE",
    "SABLE_FALLBACK_RECENTS_GESTURE",
    "SABLE_STATUS_SHADE_GESTURE_STABILITY",
    "R9_SABLE_HOME_DEVICE_ACCEPTANCE",
)

# ---------------------------------------------------------------------------
# Canonical pre-full qualification must build both Sable HOME and Quickstep.
# ---------------------------------------------------------------------------
require(
    "build/panther/build-r8-final-ui.sh",
    "SableLauncher Launcher3QuickStep",
    "R9_SABLELAUNCHER_MODULE_BUILD=PASS",
    "R9_QUICKSTEP_RECENTS_MODULE_BUILD=PASS",
    "R9_SABLE_HOME_QUICKSTEP_PREFLIGHT=PASS",
)
require(
    "build/panther/qualify-r9-physical-ux.sh",
    "FULL_TARGET_FILES_BUILD_AUTHORIZED=NO",
    "R9_PHYSICAL_UX_MODULE_QUALIFICATION=PASS",
    "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES_AFTER_MODULE_QUALIFICATION",
)

if failures:
    print("R9_SYSTEM_COHESION_CONTRACT=FAIL")
    for failure in failures:
        print(f"FAILURE={failure}")
    raise SystemExit(1)

print("R9_SYSTEM_APPEARANCE_AUTHORITY=PASS_SETTINGS_HOSTED")
print("R9_SABLELAUNCHER_HOME_ARCHITECTURE=PASS_STANDALONE")
print("R9_LAUNCHER3_HOME_ELIGIBILITY=PASS_ABSENT_SOURCE")
print("R9_QUICKSTEP_RECENTS_ONLY_ARCHITECTURE=PASS")
print("R9_LIVE_PROVIDER_CALLER_BOUNDARY=PASS_SABLELAUNCHER")
print("R9_CLOCK_DAY_NIGHT_CONTRACT=PASS_SEMANTIC")
print("R9_PHOTOS_DAY_NIGHT_CONTRACT=PASS_QUALIFIED")
print("R9_CAMERA_PRESENTATION_CONTRACT=PASS_EXPLICIT_DARK_UPSTREAM_BOUNDARY")
print("R9_READER_APPEARANCE_CONTRACT=PASS_SABLEOS_GLOBAL")
print("R9_READER_LIBRARY_CONTRACT=PASS_ACTUAL_BOOKS_CONTINUOUS")
print("R9_CONTACTS_ALPHABET_RAIL_CONTRACT=PASS")
print("R9_MEDIA_ALPHABET_RAIL_CONTRACT=PASS")
print("R9_MEDIA_LARGE_LIBRARY_ANR_CONTRACT=PASS")
print("R9_SABLE_MESSAGES_NATIVE_SMS_PEOPLE=PASS")
print("R9_SABLE_MESSAGES_WEB_CAPSULES=PASS_RETIRED")
print("R9_SABLE_MESSAGES_INTERNET_PERMISSION=PASS_ABSENT")
print("R9_SYSTEM_COHESION_CONTRACT=PASS")
