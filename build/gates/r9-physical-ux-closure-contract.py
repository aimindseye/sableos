#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

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
    "val privacySummary: String = """,
)
require(
    "patches/android-17-grapheneos-2026081300/r9_launcher3/SableQuickstepLauncher.kt",
    "PackageManager.GET_PERMISSIONS",
    "PackageInfo.REQUESTED_PERMISSION_GRANTED",
    "createContextAsUser(user, 0)",
    "buildPrivacyPermissionSummary(",
    ""permissions · none sensitive"",
    ""permissions · " + labels.joinToString(" · ")",
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
)
require(
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt",
    "text = app.privacySummary",
    "onOpenAppInfo",
)
forbid(
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt",
    "component.packageName",
)

# ---------------------------------------------------------------------------
# Global appearance: Sable Light/Dark -> Android system mode; Sable accent ->
# Quick Settings active state. GrapheneOS behavior remains in SystemUI.
# ---------------------------------------------------------------------------
require(
    "patches/android-17-grapheneos-2026081300/r9_launcher3/SableQuickstepLauncher.kt",
    "getSystemService(UiModeManager::class.java)",
    "UiModeManager.MODE_NIGHT_YES",
    "UiModeManager.MODE_NIGHT_NO",
    "rememberSystemNightModeBeforeOverride(",
    "loadSystemNightModeBeforeOverride()",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_launcher3_foundation.py",
    "android.permission.MODIFY_DAY_NIGHT_MODE",
)
require(
    "src/android/packages/apps/SableStart/src/com/sable/start/platform/StartStateRepository.kt",
    "KEY_SYSTEM_NIGHT_MODE_BEFORE_OVERRIDE",
    "rememberSystemNightModeBeforeOverride",
    "clearSystemNightModeBeforeOverride",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_ui4_systemui.py",
    "SableSystemAppearance.kt",
    "content://org.sableos.start.appearance/appearance",
    "registerContentObserver",
    "rememberSableSystemAccent",
    "background = accent.color",
    "label = accent.onColor",
    "UI4_R1_SABLE_ACCENT_PROVIDER=PASS",
)

# ---------------------------------------------------------------------------
# Duplicate messaging visibility: preserve mature transport and Android
# APP_MESSAGING fallback, remove only launcher exposure.
# ---------------------------------------------------------------------------
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_messaging_visibility.py",
    'MESSAGING_HEAD = "d125442740e85c8c630c6b3c1091046166b99187"',
    "android.intent.category.APP_MESSAGING",
    "android.provider.Telephony.SMS_DELIVER",
    "android.provider.Telephony.WAP_PUSH_DELIVER",
    "android.intent.action.RESPOND_VIA_MESSAGE",
    "R9_GRAPHENE_MESSAGING_LAUNCHER_EXPOSURE=PASS_HIDDEN",
)
require(
    "build/panther/prepare-r8-final-ui.sh",
    "R9_MESSAGING_VISIBILITY",
    "apply_r9_messaging_visibility.py",
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/HubRepository.kt",
    "Intent.CATEGORY_APP_MESSAGING",
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
)
for rel in icon_files:
    require_file(rel)
    require(rel, "<vector", "android:viewportWidth="48"")

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
    "apps/r8/reader/apply_sable_flavor.py",
    "ic_sable_reader.xml",
    'android:icon="@drawable/ic_sable_reader"',
    'android:roundIcon="@drawable/ic_sable_reader"',
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

print("R9_ALL_APPS_GRANTED_PRIVACY_SUMMARY=PASS")
print("R9_GLOBAL_LIGHT_DARK_SYSTEM_MODE_CONTRACT=PASS")
print("R9_SYSTEMUI_SABLE_ACCENT_CONTRACT=PASS")
print("R9_SINGLE_VISIBLE_MESSAGES_CONTRACT=PASS")
print("R9_FIRST_PARTY_PRODUCT_ICON_CONTRACT=PASS")
print("R9_MEDIA_READER_REMEDIATION_INCLUDED=PASS")
print("R9_ACTIVE_DEVICE_SET_CONTRACT=PASS")
print("R9_PHYSICAL_UX_CLOSURE_CONTRACT=PASS")
