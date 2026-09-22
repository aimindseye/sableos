#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]

failures: list[str] = []


def read(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        failures.append(f"missing_file={rel}")
        return ""
    return path.read_text(encoding="utf-8")


def require(rel: str, *needles: str) -> None:
    text = read(rel)
    for needle in needles:
        if needle not in text:
            failures.append(f"missing_token={rel}:{needle}")


def forbid(rel: str, *needles: str) -> None:
    text = read(rel)
    for needle in needles:
        if needle in text:
            failures.append(f"forbidden_token={rel}:{needle}")


def require_file(rel: str) -> None:
    if not (ROOT / rel).is_file():
        failures.append(f"missing_file={rel}")


# ---------------------------------------------------------------------------
# Launcher privacy summary regression
# ---------------------------------------------------------------------------
require(
    "src/android/packages/apps/SableStart/src/com/sable/start/model/AppEntry.kt",
    'val privacySummary: String = ""',
)
require(
    "patches/android-17-grapheneos-2026081300/r9_launcher3/SableQuickstepLauncher.kt",
    "PackageManager.GET_PERMISSIONS",
    "PackageInfo.REQUESTED_PERMISSION_GRANTED",
    "createContextAsUser(user, 0)",
    "buildPrivacyPermissionSummary(",
    "packageInfo.requestedPermissionsFlags ?: IntArray(0)",
    '"permissions · none sensitive"',
    '"permissions · " + labels.joinToString(" · ")',
    'label = "location"',
    'label = "camera"',
    'label = "microphone"',
    'label = "contacts"',
    'label = "phone"',
    'label = "messages"',
    'label = "calendar"',
    'label = "photos"',
    'label = "audio"',
    'label = "nearby"',
    'label = "notifications"',
    'const val GRAPHENE_MESSAGING_PACKAGE = "com.android.messaging"',
    "component.packageName == GRAPHENE_MESSAGING_PACKAGE",
)
require(
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt",
    "text = app.privacySummary",
    "onOpenAppInfo",
)
require(
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableGlyphIcon.kt",
    "SableGlyphIcon(",
    '"org.sableos.weather" -> SableGlyphs.Weather',
    '"org.sableos.calendar" -> SableGlyphs.Calendar',
    '"org.sableos.hub" -> SableGlyphs.Messages',
    "Path().apply",
    "addSvg(spec.pathData)",
    "drawPath(",
)
forbid(
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableGlyphIcon.kt",
    "androidx.core.graphics.PathParser",
    "android.util.PathParser",
    "drawIntoCanvas",
    "nativeCanvas",
)
require(
    "src/android/packages/apps/SableStart/Android.bp",
    '"src/com/sable/start/ui/SableGlyphIcon.kt"',
)
require(
    "build/panther/sync-sablestart.sh",
    "src/com/sable/start/ui/SableGlyphIcon.kt",
)
require(
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt",
    'packageNames = setOf("org.sableos.calendar")',
    'packageNames = setOf("org.sableos.hub")',
    'packageNames = setOf("org.sableos.mail")',
    'packageNames = setOf("org.sableos.weather")',
    'packageNames = setOf("org.sableos.media")',
    'packageNames = setOf("org.sableos.calculator")',
    "app.component.packageName in group.packageNames",
)
# Package names may be used internally for deterministic ordering and
# component identity, but they must never be rendered as All Apps / Peek
# user-facing copy. The product contract is "app name + privacy summary",
# not package-name disclosure.
forbid(
    "patches/android-17-grapheneos-2026081300/r9_launcher3/SableQuickstepLauncher.kt",
    "requestedPermissionsFlags.orEmpty()",
)
forbid(
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt",
    "text = app.component.packageName",
    "text = component.packageName",
    "text = app.component.flattenToString()",
    "text = app.component.flattenToShortString()",
)

# ---------------------------------------------------------------------------
# Global appearance + launcher ownership.
# Settings owns the persisted Sable appearance authority and boot restoration.
# Launcher is a client/editor. SystemUI observes the same authority.
# ---------------------------------------------------------------------------
require(
    "src/android/shared/sabledesign/src/main/java/org/sableos/design/SableGlobalAppearance.kt",
    'const val AUTHORITY = "org.sableos.appearance"',
    "writeGlobalSableAppearance(",
    "contentResolver.update(",
    "registerContentObserver",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_settings_cohesion.py",
    "SableAppearanceProvider.java",
    "SableAppearanceBootReceiver.java",
    "SableAppearanceSettings.java",
    'android.permission.MODIFY_DAY_NIGHT_MODE',
    'android:authorities="org.sableos.appearance"',
    "createDeviceProtectedStorageContext()",
    "MODE_NIGHT_NO",
    "MODE_NIGHT_YES",
    "LOCKED_BOOT_COMPLETED",
    "R9_SYSTEM_APPEARANCE_BOOT_RESTORE_SOURCE=PASS",
    "R9_SETTINGS_APPEARANCE_ENTRY=PASS",
)
require(
    "patches/android-17-grapheneos-2026081300/r9_launcher3/SableQuickstepLauncher.kt",
    "readGlobalSableAppearance(",
    "writeGlobalSableAppearance(",
    "fun isSableSurfaceActive(): Boolean",
    "LauncherState.ALL_APPS ->",
    "stateManager.goToState(LauncherState.NORMAL, false)",
    "onOpenSystemSettings = ::openSystemSettings",
)
forbid(
    "patches/android-17-grapheneos-2026081300/r9_launcher3/SableQuickstepLauncher.kt",
    "UiModeManager",
    "rememberSystemNightModeBeforeOverride(",
    "loadSystemNightModeBeforeOverride()",
    "startStateRepository.saveAppearance(",
)
forbid(
    "src/android/packages/apps/SableStart/src/com/sable/start/platform/StartStateRepository.kt",
    "KEY_SYSTEM_NIGHT_MODE_BEFORE_OVERRIDE",
    "rememberSystemNightModeBeforeOverride",
    "clearSystemNightModeBeforeOverride",
    "saveAppearance(",
    "loadAppearance(",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_launcher3_foundation.py",
    "LEGACY_MANIFEST_HEADER_REPLACEMENT",
    "LEGACY_PROVIDER_BLOCK",
    "legacy Launcher appearance ownership remains",
    "SableAppearanceProvider.kt",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_launcher_cohesion.py",
    "PortraitStatesTouchController.java",
    "NoButtonNavbarToOverviewTouchController.java",
    "isSableSurfaceActive()",
    "!mDidTouchStartInNavBar",
    "R9_SABLE_NATIVE_ALL_APPS_TOUCH_ESCAPE=PASS_BLOCKED",
    "R9_QUICKSTEP_NAVBAR_OVERVIEW_PATH=PASS_PRESERVED",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_systemui_coherence.py",
    "SableSystemAppearance.kt",
    'print(f"R9_SYSTEMUI_COHERENCE=FAIL {exc}")',
    "content://org.sableos.appearance/appearance",
    "registerContentObserver",
    "rememberSableSystemAccent",
    "LEGACY_COLOR_SELECTOR",
    "SABLE_COLOR_SELECTOR",
    "stateful tile color selector annotation",
    "R9_SYSTEMUI_EXISTING_OVERLAY_UPGRADE=YES",
    "background = accent.color",
    "label = accent.onColor",
    "R9_SYSTEMUI_SABLE_ACCENT_PROVIDER=PASS",
    "R9_SYSTEMUI_INTERACTION_SEMANTICS_PRESERVED=PASS",
)
require(
    "build/panther/prepare-r8-final-ui.sh",
    "R9_SYSTEMUI_COHERENCE",
    "R9_SETTINGS_COHERENCE",
    "R9_LAUNCHER_COHESION",
    "apply_r9_systemui_coherence.py",
    "apply_r9_settings_cohesion.py",
    "apply_r9_launcher_cohesion.py",
    "R9_GRAPHENE_MESSAGING_SUBSTRATE=PASS_PREBUILT_UNMODIFIED",
    "R9_MESSAGING_LAUNCHER_SUPPRESSION=OWNED_BY_SABLE_LAUNCHER3",
)

# ---------------------------------------------------------------------------
# Duplicate messaging visibility: GrapheneOS 2026081300 ships Messaging as a
# pinned prebuilt. Preserve that package untouched and suppress only its Sable
# launcher presentation entry. Android/default-app behavior remains owned by
# the prebuilt platform package.
# ---------------------------------------------------------------------------
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_messaging_visibility.py",
    'MESSAGING_HEAD = "d125442740e85c8c630c6b3c1091046166b99187"',
    'ANDROID_BP = MESSAGING_REPO / "Android.bp"',
    'PREBUILT_APK = MESSAGING_REPO / "prebuilt/Messaging.apk"',
    '"android_app_import {"',
    '"R9_GRAPHENE_MESSAGING_PREBUILT_IMPORT=PASS"',
    '"R9_GRAPHENE_MESSAGING_PACKAGE_RETAINED=PASS_PREBUILT"',
    '"R9_GRAPHENE_MESSAGING_SOURCE_MUTATION=NONE"',
    '"SABLE_LAUNCHER_PRESENTATION"',
)
require(
    "build/panther/prepare-r8-final-ui.sh",
    'python3 "$MESSAGING_VISIBILITY" --source "$WS" verify',
    "R9_GRAPHENE_MESSAGING_SUBSTRATE=PASS_PREBUILT_UNMODIFIED",
    "R9_MESSAGING_LAUNCHER_SUPPRESSION=OWNED_BY_SABLE_LAUNCHER3",
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/HubRepository.kt",
    "Intent.CATEGORY_APP_MESSAGING",
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/ui/HubScreen.kt",
    "if (pivot == HubPivot.Messages) 1.12f else 1f",
    "contentPadding = PaddingValues(horizontal = SableSpacing.Xs)",
    "maxLines = 1",
    "softWrap = false",
    'text = "Messages"',
    '"Grant Messages access to show conversations and send SMS."',
    '"Contacts access is optional and only improves people matching."',
    'text = "MMS / RCS"',
    'subtitle = "Write a message."',
    '"Private web session"',
    '"Services open in private, isolated web sessions when a native integration is not available."',
    '"No conversations yet."',
)
forbid(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/ui/HubScreen.kt",
    'text = "Android capability"',
    'text = "Android transport"',
    '"Sable Hub does not take the default SMS role in R8-F.',
    'subtitle = "SMS uses Android telephony capability.',
    'text = "Use transport"',
    '"SMS history is not available to Sable Hub yet."',
    '"Grant SMS access if this Sable build allows it, or use the Android transport fallback."',
    '"SMS history is not available in Sable Messages yet."',
    '"Sable Messages can read and send SMS when access is granted. MMS/RCS can open the system messaging service when needed."',
    'text = "Open MMS / RCS"',
    'subtitle = "Write an SMS here. MMS/RCS can be handed off when needed."',
)

# ---------------------------------------------------------------------------
# Repo layout: standalone SableStart build entry point is retired. Production
# Sable presentation is qualified through Launcher3/Quickstep.
# ---------------------------------------------------------------------------
require(
    "build/check-repo-layout.sh",
    "build/panther/prepare-r8-final-ui.sh",
    "build/panther/build-r8-final-ui.sh",
    "build/panther/qualify-r9-physical-ux.sh",
    "apply_r9_launcher3_foundation.py",
    "r9_launcher3/SableQuickstepLauncher.kt",
    "R9_STANDALONE_SABLESTART_BUILD_ENTRYPOINT=PASS_ABSENT",
    "R9_STANDALONE_SABLESTART_MANIFEST=PASS_ABSENT",
    "R9_SABLESTART_PRESENTATION_FILEGROUP=PASS",
    "R9_LAUNCHER3_HOSTED_SABLESTART_LAYOUT=PASS",
)
require(
    "build/check-ci-policy.py",
    "repo layout required array could not be parsed",
    "repo layout retired_sablestart array could not be parsed",
    "obsolete standalone SableStart artifact remains in required layout",
    "retired SableStart artifact missing from retired layout",
    "repo layout contract token missing",
)

# ---------------------------------------------------------------------------
# Phone + Contacts: pinned GrapheneOS 2026081300 presentation-only refresh.
# ---------------------------------------------------------------------------
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_phone_contacts_presentation.py",
    'DIALER_HEAD = "6a629762cf425002d34ecf28596813babda7d751"',
    'CONTACTS_HEAD = "e911d48c3f433633f5a8fb1a7fd865a071a09350"',
    "DIALER_TRANSFORMS",
    "CONTACTS_TRANSFORMS",
    "R9_PHONE_CONTACTS_BEHAVIORAL_SOURCE_MUTATION=NONE",
    "R9_PHONE_CONTACTS_PINNED_BASELINES=PASS",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_phone_contacts_presentation.py",
    "behavioral = [",
    'path.suffix in {".java", ".kt"}',
    "BEHAVIORAL_SOURCE_MUTATION=FAIL",
)
require(
    "build/panther/prepare-r8-final-ui.sh",
    "apply_r9_phone_contacts_presentation.py",
    'python3 "$PHONE_CONTACTS" --source "$WS" verify',
    "R9_PHONE_CONTACTS_PRESENTATION=PASS",
)
require(
    "build/panther/build-r8-final-ui.sh",
    "Launcher3QuickStep     Dialer     Contacts     DeskClock     DocumentsUI     Gallery2",
    "SableMail     SableWeather     SableCalendar",
    "R9_PHONE_MODULE_BUILD=PASS",
    "R9_CONTACTS_MODULE_BUILD=PASS",
    "R9_CLOCK_MODULE_BUILD=PASS",
    "R9_FILES_MODULE_BUILD=PASS",
    "R9_PHOTOS_MODULE_BUILD=PASS",
    "R9_SABLE_WEATHER_MODULE_BUILD=PASS",
    "R9_SABLE_CALENDAR_MODULE_BUILD=PASS",
)

require(
    "patches/android-17-grapheneos-2026081300/apply_r9_daily_driver_core_presentation.py",
    '"packages/apps/DeskClock": "7e04cd4bec8c1d9e1579eaa5b3089fe6042a0cb8"',
    '"packages/apps/DocumentsUI": "ac4670682dd0df3a9798dfb346c57f163d42f7fc"',
    '"packages/apps/Gallery2": "f5518d09c6e6953eaba6d0c7c23d5a2d766b6525"',
    '"external/Camera": "1e8ea44155ce3c023d9b1486d57a44268276c315"',
    '"external/vanadium": "57c3996dfd45e8d9b6f0b15b0753c94acb4282ef"',
    "R9_CLOCK_PRESENTATION=PASS_RESOURCE_ONLY",
    "R9_FILES_PRESENTATION=PASS_RESOURCE_ONLY",
    "R9_PHOTOS_PRESENTATION=PASS_RESOURCE_ONLY",
    "R9_CAMERA_PRESENTATION_BOUNDARY=PASS_UPSTREAM_PREPROCESSED_APK",
    "R9_VANADIUM_PRESENTATION_BOUNDARY=PASS_UPSTREAM_SECURITY_BUILD",
    "R9_CORE_APP_BEHAVIORAL_MUTATION=PASS_ABSENT",
)
require(
    "build/panther/prepare-r8-final-ui.sh",
    "apply_r9_daily_driver_core_presentation.py",
    'python3 "$DAILY_DRIVER_CORE" --source "$WS" apply',
    'python3 "$DAILY_DRIVER_CORE" --source "$WS" verify',
    "R9_DAILY_DRIVER_CORE_PRESENTATION=PASS",
)
require(
    "build/gates/r8-final-product-composition.sh",
    "apply_r9_daily_driver_core_presentation.py",
    "R9_DAILY_DRIVER_CORE_PRESENTATION=PASS_SOURCE",
)

# ---------------------------------------------------------------------------
# Sable Weather: Rust domain + Android HTTPS shell + read-only Launcher snapshot.
# ---------------------------------------------------------------------------
for rel in (
    "apps/r8/rust/crates/weather-core/src/lib.rs",
    "apps/r8/rust/crates/weather-jni/src/lib.rs",
    "apps/r8/android/weather/src/main/AndroidManifest.xml",
    "apps/r8/android/weather/src/main/java/org/sableos/weather/MainActivity.kt",
    "apps/r8/android/weather/src/main/java/org/sableos/weather/WeatherGlyph.kt",
    "apps/r8/android/weather/src/main/java/org/sableos/weather/WeatherRepository.kt",
    "apps/r8/android/weather/src/main/java/org/sableos/weather/WeatherSnapshotProvider.kt",
):
    require_file(rel)

require(
    "apps/r8/rust/crates/weather-core/src/lib.rs",
    "ProviderState",
    "build_open_meteo_url",
    "https://api.open-meteo.com/v1/forecast",
    "parse_open_meteo",
    "WeatherCondition",
    'let needle = format!("\\\"{key}\\\"");',
)
forbid(
    "apps/r8/rust/crates/weather-core/src/lib.rs",
    "http://api.open-meteo.com",
)
require(
    "apps/r8/android/weather/src/main/AndroidManifest.xml",
    'android.permission.INTERNET',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android:usesCleartextTraffic="false"',
    'android:authorities="org.sableos.weather.snapshot"',
    'android:icon="@drawable/ic_sable_weather"',
    'android:roundIcon="@drawable/ic_sable_weather"',
)
forbid(
    "apps/r8/android/weather/src/main/AndroidManifest.xml",
    "android.permission.ACCESS_FINE_LOCATION",
)
require(
    "apps/r8/android/weather/src/main/java/org/sableos/weather/MainActivity.kt",
    "SableGlobalTheme(window = window)",
    "Open-Meteo · HTTPS",
    "precise location is not required",
    "WeatherGlyph(",
)
forbid(
    "apps/r8/android/weather/src/main/java/org/sableos/weather/MainActivity.kt",
    "private fun conditionMark(",
)
for rel in (
    "apps/r8/android/weather/src/main/res/drawable/ic_weather_clear.xml",
    "apps/r8/android/weather/src/main/res/drawable/ic_weather_partly_cloudy.xml",
    "apps/r8/android/weather/src/main/res/drawable/ic_weather_cloudy.xml",
    "apps/r8/android/weather/src/main/res/drawable/ic_weather_fog.xml",
    "apps/r8/android/weather/src/main/res/drawable/ic_weather_rain.xml",
    "apps/r8/android/weather/src/main/res/drawable/ic_weather_snow.xml",
    "apps/r8/android/weather/src/main/res/drawable/ic_weather_storm.xml",
    "apps/r8/android/weather/src/main/res/drawable/ic_weather_unknown.xml",
):
    require_file(rel)
    require(rel, 'android:viewportWidth="256"', 'android:fillColor="#FFFFFFFF"')

require(
    "apps/r8/android/weather/src/main/java/org/sableos/weather/WeatherGlyph.kt",
    "Glyph geometry is sourced from the pinned Phosphor Icons regular set.",
    "painterResource(icon)",
    "R.drawable.ic_weather_clear",
    "R.drawable.ic_weather_partly_cloudy",
    "R.drawable.ic_weather_cloudy",
    "R.drawable.ic_weather_fog",
    "R.drawable.ic_weather_rain",
    "R.drawable.ic_weather_snow",
    "R.drawable.ic_weather_storm",
    "R.drawable.ic_weather_unknown",
)
forbid(
    "apps/r8/android/weather/src/main/java/org/sableos/weather/WeatherGlyph.kt",
    "Canvas(",
    "drawCloud(",
    "drawSun(",
)
require(
    "apps/r8/android/weather/src/main/java/org/sableos/weather/WeatherRepository.kt",
    "HttpsURLConnection",
    'require(url.startsWith("https://"))',
    "WeatherNative.parseForecast(json)",
)
require(
    "apps/r8/android/weather/src/main/java/org/sableos/weather/WeatherSnapshotProvider.kt",
    "Binder.getCallingUid()",
    'packageName == "com.android.launcher3"',
    ".newRow()",
    '.add(state.availability.name.uppercase())',
    "override fun insert",
    "override fun update",
    "override fun delete",
)
forbid(
    "apps/r8/android/weather/src/main/java/org/sableos/weather/WeatherSnapshotProvider.kt",
    "cursor.addRow(\n            arrayOf(",
)
require(
    "src/android/packages/apps/SableStart/src/com/sable/start/platform/LiveSurfaceRepository.kt",
    "content://org.sableos.weather.snapshot/current",
    "providerSnapshot(",
)
forbid(
    "src/android/packages/apps/SableStart/src/com/sable/start/platform/LiveSurfaceRepository.kt",
    "api.open-meteo.com",
    "HttpURLConnection",
    "HttpsURLConnection",
    "java.net.",
)
require(
    "apps/r8/export-panther-app-bundle.sh",
    "[org.sableos.weather]=SableWeather.apk",
    "weather/build/outputs/apk/debug/weather-debug.apk",
)
require(
    "product/r8/panther/Android.bp",
    'name: "SableWeather"',
    'apk: "prebuilt/SableWeather.apk"',
)
require(
    "product/r8/panther/r8-product.mk",
    "SableWeather",
)
require(
    "build/gates/verify-r8-vendor-sable-inventory.py",
    "SableWeather.apk",
    "SableCalendar.apk",
    "R8_VENDOR_SABLE_CANONICAL_APK_COUNT=10",
)
require(
    "build/panther/run-r8-release-candidate.sh",
    "R9_FIRST_PARTY_RUST_TESTS=PASS",
    ":weather:assembleDebug",
    ":calendar:assembleDebug",
    "R9_SOURCE_BOUND_TEN_APK_FREEZE=PASS",
)

# ---------------------------------------------------------------------------
# Sable Calendar + privacy-safe Live surface.
# Calendar/Messages/Mail/Media own sensitive data and export bounded,
# Launcher3-only snapshots. Launcher itself only requests local photo access.
# ---------------------------------------------------------------------------
for rel in (
    "apps/r8/android/calendar/build.gradle.kts",
    "apps/r8/android/calendar/src/main/AndroidManifest.xml",
    "apps/r8/android/calendar/src/main/java/org/sableos/calendar/MainActivity.kt",
    "apps/r8/android/calendar/src/main/java/org/sableos/calendar/CalendarRepository.kt",
    "apps/r8/android/calendar/src/main/java/org/sableos/calendar/CalendarSnapshotProvider.kt",
    "apps/r8/android/hub/src/main/java/org/sableos/hub/HubSnapshotProvider.kt",
    "apps/r8/android/media/src/main/java/org/sableos/media/MediaSnapshotProvider.kt",
    "apps/r8/android/media/src/main/java/org/sableos/media/MediaSnapshotStore.kt",
):
    require_file(rel)

require(
    "apps/r8/android/calendar/src/main/AndroidManifest.xml",
    "android.permission.READ_CALENDAR",
    "android.permission.WRITE_CALENDAR",
    'android:authorities="org.sableos.calendar.snapshot"',
    'android:authorities="org.sableos.appearance"',
)
require(
    "apps/r8/android/calendar/src/main/java/org/sableos/calendar/CalendarRepository.kt",
    "CalendarContract.Instances.CONTENT_URI",
    "CalendarContract.Events.CONTENT_URI",
    "CalendarContract.Reminders.CONTENT_URI",
    "CalendarContract.Reminders.MINUTES, 15",
    "CalendarSnapshot",
)
require(
    "apps/r8/android/calendar/src/main/java/org/sableos/calendar/MainActivity.kt",
    "SableGlobalTheme(window = window)",
    "contentColor = MaterialTheme.colorScheme.onBackground",
    'Agenda("AGENDA")',
    'Month("MONTH")',
    'NewEvent("NEW")',
    "repository.createEvent(",
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
        'if ("com.android.launcher3" !in packages)',
        "SecurityException(",
        "UnsupportedOperationException",
    )

require(
    "apps/r8/mail/apply_sable_flavor.py",
    "SableMailSnapshotProvider.kt",
    "NotificationManager::class.java",
    "Notification.CATEGORY_EMAIL",
    "Notification.CATEGORY_MESSAGE",
    'if ("com.android.launcher3" !in packages)',
    "SecurityException(",
    "content://org.sableos.mail.snapshot/current",
)
require(
    "apps/r8/mail/verify_sable_mail.py",
    "SABLE_MAIL_PRIVACY_SAFE_LIVE_SNAPSHOT=PASS_NOTIFICATION_COUNT_ONLY",
    'android:authorities="org.sableos.mail.snapshot"',
)
require(
    "apps/r8/android/media/src/main/java/org/sableos/media/PlaybackService.kt",
    "MediaSnapshotStore.update(",
    "MediaSnapshotStore.clear(this)",
)
require(
    "src/android/packages/apps/SableStart/src/com/sable/start/platform/LiveSurfaceRepository.kt",
    "content://org.sableos.weather.snapshot/current",
    "content://org.sableos.calendar.snapshot/current",
    "content://org.sableos.hub.snapshot/current",
    "content://org.sableos.mail.snapshot/current",
    "content://org.sableos.media.snapshot/current",
    "OBSERVED_URIS",
    "Manifest.permission.READ_MEDIA_IMAGES",
)
forbid(
    "src/android/packages/apps/SableStart/src/com/sable/start/platform/LiveSurfaceRepository.kt",
    "Manifest.permission.READ_CALENDAR",
    "Manifest.permission.READ_MEDIA_AUDIO",
    "delay(60_000",
)
require(
    "patches/android-17-grapheneos-2026081300/r9_launcher3/SableQuickstepLauncher.kt",
    "LiveSurfaceRepository.OBSERVED_URIS.forEach",
    "contentResolver.registerContentObserver(",
    "liveRefreshGeneration.value += 1",
    "contentResolver.unregisterContentObserver(liveContentObserver)",
)
forbid(
    "patches/android-17-grapheneos-2026081300/r9_launcher3/SableQuickstepLauncher.kt",
    "add(Manifest.permission.READ_CALENDAR)",
    "add(Manifest.permission.READ_MEDIA_AUDIO)",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_launcher3_foundation.py",
    'android:authorities="org.sableos.calendar.snapshot"',
    'android:authorities="org.sableos.hub.snapshot"',
    'android:authorities="org.sableos.mail.snapshot"',
    'android:authorities="org.sableos.media.snapshot"',
    'assert "android.permission.READ_CALENDAR" not in patched_manifest',
    'assert "android.permission.READ_MEDIA_AUDIO" not in patched_manifest',
)
require(
    "apps/r8/export-panther-app-bundle.sh",
    "[org.sableos.calendar]=SableCalendar.apk",
    "calendar/build/outputs/apk/debug/calendar-debug.apk",
)
require(
    "product/r8/panther/Android.bp",
    'name: "SableCalendar"',
    'apk: "prebuilt/SableCalendar.apk"',
    'overrides: ["Calendar"]',
)
require(
    "build/gates/r8-final-target-files.sh",
    '"Calendar.apk"',
)
require(
    "product/r8/panther/r8-product.mk",
    "SableCalendar",
)

# ---------------------------------------------------------------------------
# SMS/MMS blocking: Android platform blocker remains authoritative. Automatic
# content spam classification is deliberately deferred until it can live in
# the default SMS delivery path.
# ---------------------------------------------------------------------------
require_file("build/gates/r9-sms-mms-blocking-contract.py")
require(
    "build/gates/r9-sms-mms-blocking-contract.py",
    "R9_BLOCKED_NUMBER_PLATFORM_CONTRACT=PASS",
    "R9_GRAPHENE_MESSAGING_BLOCKING_BOUNDARY=PASS",
    "R9_SABLE_HUB_SMS_DELIVERY_OWNERSHIP=PASS_ABSENT",
    "R9_SMS_MMS_SPAM_CLASSIFICATION=DEFERRED_DEFAULT_SMS_INTEGRATION_REQUIRED",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_phone_contacts_presentation.py",
    "verify_blocking_substrate",
    "R9_BLOCKED_NUMBER_PLATFORM_SUBSTRATE=PASS",
    "R9_BLOCKED_NUMBER_SETTINGS_UI=PASS",
    "R9_SMS_MMS_BLOCKING_OWNER=ANDROID_BLOCKED_NUMBER_PROVIDER",
)
require(
    "docs/R9_SMS_MMS_BLOCKING_SPAM.md",
    "Sable Hub / Sable Messages does not become a second SMS transport stack",
    "Automatic SMS/MMS spam classification",
    "medium-to-high",
)

# ---------------------------------------------------------------------------
# Production first-party icon contract.
# ---------------------------------------------------------------------------
icon_files = (
    "apps/r8/android/calculator/src/main/res/drawable/ic_sable_calculator.xml",
    "apps/r8/android/media/src/main/res/drawable/ic_sable_media.xml",
    "apps/r8/android/hub/src/main/res/drawable/ic_sable_messages.xml",
    "apps/r8/android/games/src/sudoku/res/drawable/ic_sable_game.xml",
    "apps/r8/android/games/src/minesweeper/res/drawable/ic_sable_game.xml",
    "apps/r8/android/games/src/game2048/res/drawable/ic_sable_game.xml",
    "apps/r8/android/weather/src/main/res/drawable/ic_sable_weather.xml",
    "apps/r8/android/calendar/src/main/res/drawable/ic_sable_calendar.xml",
)
for rel in icon_files:
    require_file(rel)
    require(
        rel,
        "<vector",
        'android:viewportWidth="256"',
        'android:fillColor="#161C24"',
        'android:fillColor="#F7F9FC"',
    )

require(
    "apps/r8/android/calculator/src/main/AndroidManifest.xml",
    'android:icon="@drawable/ic_sable_calculator"',
    'android:roundIcon="@drawable/ic_sable_calculator"',
)
require(
    "apps/r8/android/media/src/main/AndroidManifest.xml",
    'android:icon="@drawable/ic_sable_media"',
    'android:roundIcon="@drawable/ic_sable_media"',
)
require(
    "apps/r8/android/hub/src/main/AndroidManifest.xml",
    'android:icon="@drawable/ic_sable_messages"',
    'android:roundIcon="@drawable/ic_sable_messages"',
)
require(
    "apps/r8/android/games/src/main/AndroidManifest.xml",
    'android:icon="@drawable/ic_sable_game"',
    'android:roundIcon="@drawable/ic_sable_game"',
)
require(
    "apps/r8/android/weather/src/main/AndroidManifest.xml",
    'android:icon="@drawable/ic_sable_weather"',
    'android:roundIcon="@drawable/ic_sable_weather"',
)
require(
    "apps/r8/android/calendar/src/main/AndroidManifest.xml",
    'android:icon="@drawable/ic_sable_calendar"',
    'android:roundIcon="@drawable/ic_sable_calendar"',
    'android:authorities="org.sableos.calendar.snapshot"',
)
require(
    "apps/r8/reader/apply_sable_flavor.py",
    "ic_sable_reader.xml",
    'android:icon="@drawable/ic_sable_reader"',
    'android:roundIcon="@drawable/ic_sable_reader"',
    'sable_debug_manifest_dir = mobile_root / "leisure" / "src" / "sableDebug"',
    'tools:replace="android:icon,android:roundIcon,android:label"',
    'SABLE_READER_VARIANT_MANIFEST_IDENTITY_OVERRIDE=PASS',
    "appearance = rememberGlobalSableAppearance()",
)
require(
    "apps/r8/mail/apply_sable_flavor.py",
    "ic_sable_mail.xml",
    'android:icon="@drawable/ic_sable_mail"',
)

# Media/Reader physical remediation remains part of the same pre-image closure.
require(
    "build/gates/r9-physical-remediation-contract.py",
    "R9_MEDIA_LARGE_LIBRARY_LAZY_RENDERING=PASS",
    "R9_MEDIA_QUEUE_TICKER_BOUNDED=PASS",
    "R9_MEDIA_IMPORT_OFF_MAIN_THREAD=PASS",
    "R9_READER_GLOBAL_THEME_CONTRACT=PASS",
    "R9_READER_READIUM_APPEARANCE_BRIDGE=PASS",
    "R9_READER_EXPLICIT_SEPIA_EINK_OVERRIDES=PASS",
)

# ---------------------------------------------------------------------------
# Canonical pre-full qualification + runtime identity audit.
# ---------------------------------------------------------------------------
require(
    "build/gates/r9-system-cohesion-contract.py",
    "R9_PLATFORM_SURFACE_CLASSIFICATION=PASS",
    "R9_SABLE_OWNED_BRANDING_CONTRACT=PASS",
    "R9_INTENTIONAL_UPSTREAM_BOUNDARY=PASS",
    "R9_WS6_SOURCE_AUDIT=PASS",
    "R9_WS7_INTEGRATION_CONTRACT=PASS",
    "R9_SYSTEM_COHESION_CONTRACT=PASS",
)
require(
    "docs/R9_PLATFORM_SURFACE_CLASSIFICATION.md",
    "SABLE_OWNED",
    "SABLE_PRESENTED_ANDROID",
    "INTENTIONALLY_UPSTREAM",
    "R9_SABLE_USER_VISIBLE_BRANDING_AUDIT=PASS",
)
require(
    "build/panther/qualify-r9-physical-ux.sh",
    "r9-system-cohesion-contract.py",
    "R9_SYSTEM_COHESION_STATIC_CONTRACT=PASS",
)

require(
    "build/sable.sh",
    "qualify [suite]",
    "SABLE_DEVICE_QUALIFY_SUPPORTED",
    'sable_device_qualify "$RELEASE" "$SUITE"',
)
require(
    "build/devices/panther.sh",
    "SABLE_DEVICE_QUALIFY_SUPPORTED=YES",
    "SABLE_DEVICE_DEFAULT_QUALIFICATION_SUITE=physical-ux",
    "qualify-r9-physical-ux.sh",
    "R9:identity|r9:identity",
)
require(
    "build/panther/qualify-r9-physical-ux.sh",
    "FULL_TARGET_FILES_BUILD_AUTHORIZED=NO",
    "SABLE_QUALIFICATION_ONLY=YES",
    "R9_MAC_VISUAL_ACCEPTANCE=WAIVED_BY_USER_FOR_R9",
    "R9_PHYSICAL_PANTHER_VISUAL_ACCEPTANCE=REQUIRED",
    "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES_AFTER_MODULE_QUALIFICATION",
)
require(
    "build/gates/r8-build-driver-contract.sh",
    "R9_BUILD_DRIVER_TEN_APK_INVENTORY=PASS",
    "R9_LAUNCHER_VISUAL_ACCEPTANCE_WIRING=PASS",
    "R9_LAUNCHER_VISUAL_ACCEPTANCE_EXECUTION=DEFERRED_RELEASE_PROFILE",
    "R9_BUILD_DRIVER_VISUAL_ACCEPTANCE_SCOPE=FAIL_FULL_CI_EXECUTION",
    "R9_BUILD_DRIVER_VISUAL_ACCEPTANCE_SCOPE=FAIL_RELEASE_EXECUTION_MISSING",
)
require(
    "build/local-ci/run.sh",
    "r9-sms-mms-blocking-contract.py",
    "r9-first-party-app-icon-contract.py",
    ":weather:assembleDebug",
    ":weather:lintDebug",
    ":weather:detekt",
    ":weather:ktlintCheck",
    ":calendar:assembleDebug",
    ":calendar:lintDebug",
    ":calendar:detekt",
    ":calendar:ktlintCheck",
    "weather-debug.apk",
    "calendar-debug.apk",
    "org.sableos.weather",
    "org.sableos.calendar",
)
require(
    "build/panther/run-r8-release-candidate.sh",
    "NETWORK_FETCH_AUTHORIZED=NO",
    "./gradlew     --offline",
    "./gradlew         --offline",
    'SABLE_QUALIFICATION_ONLY="$SABLE_QUALIFICATION_ONLY"',
)
require(
    "build/panther/build-r8-final-ui.sh",
    "SABLE_BUILD_STAGE",
    "COMPOSITION_QUALIFICATION_ONLY=YES",
    "R9_PHYSICAL_UX_MODULE_QUALIFICATION=PASS",
    "FULL_TARGET_FILES_BUILD_PERFORMED=NO",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_ui5c_ui6_system_surfaces.py",
    "--allow-framework-untracked",
    "--allow-framework-modified",
    "UI6_ALLOWED_LATER_FRAMEWORK_DIRT_MISSING=",
    "UI6_ALLOWED_LATER_FRAMEWORK_MODIFIED_UNKNOWN=",
    "framework_for_ui6 = actual_framework - allowed_later_dirt",
    "allowed_later_framework_modified",
)
require(
    "build/gates/r9-launcher-visual-acceptance.py",
    "R9_MAC_VISUAL_ACCEPTANCE=WAIVED_BY_USER_FOR_R9",
    "R9_L6_VISUAL_REVIEW_STATUS=WAIVED_MAC_DEFERRED_PHYSICAL_PANTHER",
    "R9_L6_VISUAL_REVIEW_SCOPE=PHYSICAL_PANTHER_REQUIRED",
    "R9_PHYSICAL_PANTHER_VISUAL_ACCEPTANCE=REQUIRED",
    "R9_FINAL_VISUAL_AUTHORITY=PHYSICAL_PANTHER",
    "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES",
)
require(
    "docs/R9_FINAL_UI_RUNTIME_ACCEPTANCE.md",
    "R9_MAC_VISUAL_ACCEPTANCE=WAIVED_BY_USER_FOR_R9",
    "R9_PHYSICAL_PANTHER_VISUAL_ACCEPTANCE=REQUIRED",
    "R9_FINAL_VISUAL_AUTHORITY=PHYSICAL_PANTHER",
)

require(
    "build/gates/r8-final-product-composition.sh",
    "--allow-framework-untracked",
    "packages/SystemUI/src/com/android/systemui/sable/SableSystemAppearance.kt",
    "--allow-framework-modified",
    "packages/SystemUI/src/com/android/systemui/qs/panels/ui/compose/infinitegrid/Tile.kt",
    "apply_r9_systemui_coherence.py",
    "R9_SYSTEMUI_COHERENCE_SOURCE=PASS",
    "R9_LAUNCHER_VISUAL_ACCEPTANCE_SEAL=WAIVED_MAC_DEFERRED_PHYSICAL_PANTHER",
    "R9_MAC_VISUAL_ACCEPTANCE=WAIVED_BY_USER_FOR_R9",
    "R9_PHYSICAL_PANTHER_VISUAL_ACCEPTANCE=REQUIRED",
    "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=YES_AFTER_MODULE_QUALIFICATION",
)
require(
    "tests/systemui/device/r9_identity_audit.sh",
    "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY",
    "android:string/android_system_label",
    "android:string/adb_active_notification_title",
    "R9_SYSTEM_IDENTITY_AUDIT=PASS_READ_ONLY",
)
require(
    "tests/systemui/device/r9_final_ui_runtime_audit.sh",
    "R9_FINAL_UI_VANADIUM_PACKAGE=PASS",
    "R9_FINAL_UI_DEFAULT_BROWSER=PASS_VANADIUM",
    "R9_FINAL_UI_GOOGLE_CHROME_PRELOAD=PASS_ABSENT",
    "R9_FINAL_UI_GRAPHENE_MESSAGING_PACKAGE=PASS",
    "R9_FINAL_UI_GOOGLE_MESSAGES_PRELOAD=PASS_ABSENT",
    "R9_FINAL_UI_SMS_ROLE=PASS_GRAPHENE_MESSAGING",
    "R9_FINAL_UI_SABLE_MESSAGES_PACKAGE=PASS",
    "R9_FINAL_UI_APPEARANCE_SABLE_APPS=PENDING_VISUAL_DEVICE_REVIEW",
    "R9_FINAL_UI_APPEARANCE_PLATFORM_APPS=PENDING_VISUAL_DEVICE_REVIEW",
)
require(
    "docs/R9_FINAL_UI_RUNTIME_ACCEPTANCE.md",
    "app.vanadium.browser",
    "com.android.messaging",
    "com.google.android.apps.messaging",
    "com.android.chrome",
    "WhatsApp",
    "LinkedIn",
    "Instagram",
    "Facebook / Messenger",
    "Sable appearance has one system authority",
    "content://org.sableos.appearance/appearance",
    "Settings appearance selection",
    "persisted device-protected state",
    "A reboot while explicit Dark or Light is selected",
    "Reader additionally maps normal Readium page Light/Dark",
    "The Mac mini is not required for this closure",
    "R9_SABLE_APPEARANCE_BOOT_RESTORE=PASS",
    "R9_SABLE_SYSTEM_NIGHT_PROPAGATION=PASS",
    "R9_SABLE_READER_APPEARANCE=PASS",
    "R9_FINAL_UI_SABLE_CALENDAR_PACKAGE=PASS",
    "R9_FINAL_UI_PLATFORM_CALENDAR_PRELOAD=PASS_ABSENT",
    "R9_FINAL_UI_LIVE_PROVIDER_CALLER_BOUNDARY=PASS",
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/HubModels.kt",
    'id = "whatsapp"',
    'startUrl = "https://web.whatsapp.com/"',
    'id = "instagram"',
    'startUrl = "https://www.instagram.com/direct/inbox/"',
    'id = "messenger"',
    'startUrl = "https://www.messenger.com/"',
    'id = "linkedin"',
    'startUrl = "https://www.linkedin.com/messaging/"',
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/web/ProviderCapsuleActivity.kt",
    "WebView.setDataDirectorySuffix(provider.id)",
    "WebSettings.MIXED_CONTENT_NEVER_ALLOW",
    "setAcceptThirdPartyCookies",
    'scheme == "https"',
)

# Active target set only.
for rel in (
    "build/devices/panther.sh",
    "build/devices/titan2.sh",
    "build/devices/titan2-elite.sh",
    "build/devices/q27.sh",
):
    require_file(rel)
if (ROOT / "build/devices/q25.sh").exists():
    failures.append("active_q25_device_adapter_present")

if failures:
    print("R9_PHYSICAL_UX_CLOSURE_CONTRACT=FAIL")
    for failure in failures:
        print(f"FAILURE={failure}")
    raise SystemExit(1)

self_tests = (
    (
        "R9_MESSAGING_VISIBILITY_SELF_TEST",
        ROOT
        / "patches/android-17-grapheneos-2026081300"
        / "apply_r9_messaging_visibility.py",
    ),
    (
        "R9_SYSTEMUI_COHERENCE_SELF_TEST",
        ROOT
        / "patches/android-17-grapheneos-2026081300"
        / "apply_r9_systemui_coherence.py",
    ),
    (
        "R9_SETTINGS_COHERENCE_SELF_TEST",
        ROOT
        / "patches/android-17-grapheneos-2026081300"
        / "apply_r9_settings_cohesion.py",
    ),
    (
        "R9_LAUNCHER_COHESION_SELF_TEST",
        ROOT
        / "patches/android-17-grapheneos-2026081300"
        / "apply_r9_launcher_cohesion.py",
    ),
    (
        "R9_LAUNCHER3_FOUNDATION_SELF_TEST",
        ROOT
        / "patches/android-17-grapheneos-2026081300"
        / "apply_r9_launcher3_foundation.py",
    ),
    (
        "R9_PHONE_CONTACTS_PRESENTATION_SELF_TEST",
        ROOT
        / "patches/android-17-grapheneos-2026081300"
        / "apply_r9_phone_contacts_presentation.py",
    ),
)

for marker, script in self_tests:
    result = subprocess.run(
        [sys.executable, str(script), "--self-test"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if result.stdout:
        print(result.stdout, end="")
    if result.returncode != 0:
        print(f"{marker}=FAIL rc={result.returncode}")
        raise SystemExit(result.returncode)
    print(f"{marker}=PASS")

print("R9_ALL_APPS_GRANTED_PRIVACY_SUMMARY=PASS")
print("R9_SYSTEM_APPEARANCE_AUTHORITY_CONTRACT=PASS_SETTINGS_HOSTED")
print("R9_GLOBAL_LIGHT_DARK_SYSTEM_MODE_CONTRACT=PASS")
print("R9_APPEARANCE_BOOT_RESTORE_CONTRACT=PASS")
print("R9_SABLE_NATIVE_LAUNCHER_ESCAPE_CONTRACT=PASS_BLOCKED")
print("R9_SYSTEMUI_SABLE_ACCENT_CONTRACT=PASS")
print("R9_SINGLE_VISIBLE_MESSAGES_CONTRACT=PASS")
print("R9_MESSAGES_USER_FACING_COPY=PASS_NO_TRANSPORT_IMPLEMENTATION_DETAIL")
print("R9_CALENDAR_DARK_CONTENT_COLOR=PASS")
print("R9_FIRST_PARTY_PRODUCT_ICON_CONTRACT=PASS")
print("R9_PHONE_CONTACTS_PRESENTATION_CONTRACT=PASS")
print("R9_DAILY_DRIVER_CORE_PRESENTATION_CONTRACT=PASS")
print("R9_SABLE_CALENDAR_PRODUCT_CONTRACT=PASS")
print("R9_LIVE_SURFACE_PRIVACY_BOUNDARY=PASS_LAUNCHER_SNAPSHOT_ONLY")
print("R9_LIVE_SURFACE_REFRESH=PASS_EVENT_AND_LIFECYCLE_DRIVEN")
print("R9_SMS_MMS_BLOCKING_PLATFORM_CONTRACT=PASS")
print("R9_SMS_MMS_SPAM_CLASSIFICATION_BOUNDARY=PASS")
print("R9_SABLE_WEATHER_PRODUCT_CONTRACT=PASS")
print("R9_WEATHER_JSON_KEY_PARSER_CONTRACT=PASS")
print("R9_WEATHER_CURSOR_ROW_TYPE_CONTRACT=PASS")
print("R9_WEATHER_CONDITION_GLYPH_CONTRACT=PASS_PHOSPHOR_PINNED_OPEN_SOURCE")
print("R9_SOURCE_BOUND_TEN_APK_CONTRACT=PASS")
print("R9_BUILD_DRIVER_TEN_APK_CONTRACT=PASS")
print("R9_PREIMAGE_VISUAL_ACCEPTANCE_SCOPE=PASS_DEFERRED_RELEASE")
print("R9_VISUAL_REVIEW_MINSDK30_PACKAGEINFO_COMPAT=PASS")
print("R9_VISUAL_REVIEW_APPEARANCE_PROVIDER_FIDELITY=RETIRED_SYSTEM_AUTHORITY_PHYSICAL_ONLY")
print("R9_VISUAL_REVIEW_CROSS_APP_THEME_FIDELITY=DEFERRED_PHYSICAL_PANTHER")
print("R9_VISUAL_REVIEW_HOST_BROWSER_SCOPE=PASS_FILTERED_DEFERRED_PANTHER")
print("R9_START_PACKAGE_IDENTITY_PREFERENCE=PASS")
print("R9_MEDIA_READER_REMEDIATION_INCLUDED=PASS")
print("R9_READER_READIUM_APPEARANCE_CONTRACT=PASS")
print("R9_CANONICAL_PRE_FULL_QUALIFICATION=PASS")
print("R9_RUNTIME_SYSTEM_IDENTITY_AUDIT_CONTRACT=PASS")
print("R9_FINAL_UI_RUNTIME_ACCEPTANCE_CONTRACT=PASS")
print("R9_SABLE_MESSAGES_PROVIDER_CAPSULES=PASS_4")
print("R9_PLATFORM_SURFACE_CLASSIFICATION_CONTRACT=PASS")
print("R9_SYSTEM_COHESION_INTEGRATION_GATE=PASS")
print("R9_ACTIVE_DEVICE_SET_CONTRACT=PASS")
print("R9_PHYSICAL_UX_CLOSURE_CONTRACT=PASS")
