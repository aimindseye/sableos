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
)
require(
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt",
    "text = app.privacySummary",
    "onOpenAppInfo",
)
# Package names may be used internally for deterministic ordering and
# component identity, but they must never be rendered as All Apps / Peek
# user-facing copy. The product contract is "app name + privacy summary",
# not package-name disclosure.
forbid(
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt",
    "text = app.component.packageName",
    "text = component.packageName",
    "text = app.component.flattenToString()",
    "text = app.component.flattenToShortString()",
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
    "patches/android-17-grapheneos-2026081300/apply_r9_systemui_coherence.py",
    "SableSystemAppearance.kt",
    "content://org.sableos.start.appearance/appearance",
    "registerContentObserver",
    "rememberSableSystemAccent",
    "background = accent.color",
    "label = accent.onColor",
    "R9_SYSTEMUI_SABLE_ACCENT_PROVIDER=PASS",
    "R9_SYSTEMUI_INTERACTION_SEMANTICS_PRESERVED=PASS",
)
require(
    "build/panther/prepare-r8-final-ui.sh",
    "R9_SYSTEMUI_COHERENCE",
    "apply_r9_systemui_coherence.py",
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
    require(rel, "<vector", 'android:viewportWidth="48"')

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
)

# ---------------------------------------------------------------------------
# Canonical pre-full qualification + runtime identity audit.
# ---------------------------------------------------------------------------
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
    "NEXT_FULL_PANTHER_BUILD_AUTHORIZED=NO_PENDING_VISUAL_REVIEW",
)
require(
    "build/panther/run-r8-release-candidate.sh",
    "NETWORK_FETCH_AUTHORIZED=NO",
    "./gradlew     --offline",
    "./gradlew         --offline",
)
require(
    "build/panther/build-r8-final-ui.sh",
    "SABLE_BUILD_STAGE",
    "R9_PHYSICAL_UX_MODULE_QUALIFICATION=PASS",
    "FULL_TARGET_FILES_BUILD_PERFORMED=NO",
)
require(
    "tests/systemui/device/r9_identity_audit.sh",
    "DEVICE_CONTACT_AUTHORIZED=YES_READ_ONLY",
    "android:string/android_system_label",
    "android:string/adb_active_notification_title",
    "R9_SYSTEM_IDENTITY_AUDIT=PASS_READ_ONLY",
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
        "R9_LAUNCHER3_FOUNDATION_SELF_TEST",
        ROOT
        / "patches/android-17-grapheneos-2026081300"
        / "apply_r9_launcher3_foundation.py",
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
print("R9_GLOBAL_LIGHT_DARK_SYSTEM_MODE_CONTRACT=PASS")
print("R9_SYSTEMUI_SABLE_ACCENT_CONTRACT=PASS")
print("R9_SINGLE_VISIBLE_MESSAGES_CONTRACT=PASS")
print("R9_FIRST_PARTY_PRODUCT_ICON_CONTRACT=PASS")
print("R9_MEDIA_READER_REMEDIATION_INCLUDED=PASS")
print("R9_CANONICAL_PRE_FULL_QUALIFICATION=PASS")
print("R9_RUNTIME_SYSTEM_IDENTITY_AUDIT_CONTRACT=PASS")
print("R9_ACTIVE_DEVICE_SET_CONTRACT=PASS")
print("R9_PHYSICAL_UX_CLOSURE_CONTRACT=PASS")
