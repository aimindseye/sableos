#!/usr/bin/env python3
"""R9 system-cohesion source contract.

This is a repository-only gate. It does not mutate Android source, build,
contact a device, or claim physical acceptance. It binds WS0-WS6 architecture
and ensures WS7 qualification cannot regress to the rejected Launcher-owned
appearance / native Launcher escape model.
"""

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


def require_absent(rel: str) -> None:
    if (ROOT / rel).exists():
        failures.append(f"must_be_absent={rel}")


# WS0: rejected physical candidate + serial closure contract.
require(
    "docs/R9_SYSTEM_COHESION_CLOSURE.md",
    "physical R9 candidate rejected",
    "WS1 — System-owned appearance authority",
    "WS2 — Launcher and Quickstep ownership",
    "WS3 — Sable Settings control center",
    "WS4 — SystemUI and key system surfaces",
    "WS5 — Core apps and Reader",
    "WS6 — Residual platform and branding audit",
    "WS7 — Integrated pre-image qualification",
    "WS8 — Fresh Panther candidate and physical acceptance",
)
require(
    "docs/R9_FINAL_UI_RUNTIME_ACCEPTANCE.md",
    "R9_SABLE_NATIVE_LAUNCHER_ESCAPE=PASS_ABSENT",
    "R9_SABLE_APPEARANCE_BOOT_RESTORE=PASS",
    "R9_SABLE_USER_VISIBLE_BRANDING_AUDIT=PASS",
    "R9_PHYSICAL_DAILY_DRIVER_ACCEPTANCE=PASS",
)

# WS1: one Settings-hosted system appearance authority.
require(
    "src/android/shared/sabledesign/src/main/java/org/sableos/design/SableGlobalAppearance.kt",
    'const val AUTHORITY = "org.sableos.appearance"',
    "writeGlobalSableAppearance(",
    "contentResolver.update(",
    "registerContentObserver",
)
for rel in (
    "apps/r8/android/calculator/src/main/AndroidManifest.xml",
    "apps/r8/android/calendar/src/main/AndroidManifest.xml",
    "apps/r8/android/games/src/main/AndroidManifest.xml",
    "apps/r8/android/hub/src/main/AndroidManifest.xml",
    "apps/r8/android/media/src/main/AndroidManifest.xml",
    "apps/r8/android/weather/src/main/AndroidManifest.xml",
    "apps/r8/mail/apply_sable_flavor.py",
    "apps/r8/reader/apply_sable_flavor.py",
):
    require(rel, "org.sableos.appearance")
    forbid(rel, "org.sableos.start.appearance")

require_absent(
    "src/android/packages/apps/SableStart/src/com/sable/start/platform/"
    "SableAppearanceProvider.kt"
)
forbid(
    "src/android/packages/apps/SableStart/src/com/sable/start/platform/"
    "StartStateRepository.kt",
    "loadAppearance(",
    "saveAppearance(",
    "KEY_SYSTEM_NIGHT_MODE_BEFORE_OVERRIDE",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_settings_cohesion.py",
    "SableAppearanceProvider.java",
    "SableAppearanceBootReceiver.java",
    "SableAppearanceSettings.java",
    'android.permission.MODIFY_DAY_NIGHT_MODE',
    'android:authorities="org.sableos.appearance"',
    "createDeviceProtectedStorageContext()",
    "LOCKED_BOOT_COMPLETED",
    "R9_SYSTEM_APPEARANCE_BOOT_RESTORE_SOURCE=PASS",
)

# WS2: Sable owns all HOME-facing presentation; Quickstep only escapes for
# genuine Recents/Overview.
require(
    "patches/android-17-grapheneos-2026081300/r9_launcher3/"
    "SableQuickstepLauncher.kt",
    "readGlobalSableAppearance(",
    "writeGlobalSableAppearance(",
    "fun isSableSurfaceActive(): Boolean",
    "LauncherState.ALL_APPS ->",
    "stateManager.goToState(LauncherState.NORMAL, false)",
    "onOpenSystemSettings = ::openSystemSettings",
)
forbid(
    "patches/android-17-grapheneos-2026081300/r9_launcher3/"
    "SableQuickstepLauncher.kt",
    "UiModeManager",
    "startStateRepository.saveAppearance(",
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
    "src/android/packages/apps/SableStart/src/com/sable/start/ui/SableStartScreen.kt",
    "SableControlShortcut(",
    "SableStartDestination.Appearance",
    "private fun AppsScreen(",
    "private fun SearchScreen(",
    "SableStartDestination.Peek",
    "text = app.privacySummary",
)

# WS3/WS4: Settings + SystemUI consume the same system contract while existing
# Android/GrapheneOS enforcement remains underneath.
require(
    "patches/android-17-grapheneos-2026081300/apply_ui5a_settings.py",
    "SABLE_UI5A_SENSITIVE_SUMMARY=EFFECTIVE_PERMISSION_GRANTS_ONLY",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_ui5b_app_security.py",
    "SABLE_UI5B_MUTATING_CONTROLS=NONE",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_ui5c_ui6_system_surfaces.py",
    "--allow-settings-untracked",
    "--allow-settings-modified",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_systemui_coherence.py",
    "content://org.sableos.appearance/appearance",
    "rememberSableSystemAccent",
    "R9_SYSTEMUI_SABLE_ACCENT_PROVIDER=PASS",
    "R9_SYSTEMUI_INTERACTION_SEMANTICS_PRESERVED=PASS",
)

# WS5: first-party/core appearance, with explicit Reader page bridge.
require(
    "apps/r8/reader/apply_sable_flavor.py",
    "val effectiveEpubPreferences =",
    "epubPreferences.theme == Theme.SEPIA",
    "isEink -> epubPreferences.copy(theme = Theme.LIGHT)",
    "theme = if (sableDark) Theme.DARK else Theme.LIGHT",
    "submitPreferences(effectiveEpubPreferences)",
    "R9_READER_READIUM_APPEARANCE_BRIDGE=PASS",
    "R9_READER_READING_OVERRIDES=SEPIA_EINK_ONLY",
)
require(
    "build/gates/r9-physical-remediation-contract.py",
    "R9_READER_READIUM_APPEARANCE_BRIDGE=PASS",
    "R9_READER_EXPLICIT_SEPIA_EINK_OVERRIDES=PASS",
)

# WS6: product-shell classification is explicit and does not use unsafe global
# rebranding of truthful upstream implementation identifiers.
require(
    "docs/R9_PLATFORM_SURFACE_CLASSIFICATION.md",
    "SABLE_OWNED",
    "SABLE_PRESENTED_ANDROID",
    "INTENTIONALLY_UPSTREAM",
    "PermissionController",
    "Package installer / package verifier flows",
    "Chooser / Sharesheet",
    "Accounts / credential provider flows",
    "Accessibility service flows",
    "R9_SABLE_USER_VISIBLE_BRANDING_AUDIT=PASS",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_sable_branding.py",
    "Internal GrapheneOS package/API identifiers",
    "Welcome to SableOS",
    "SableOS icon",
    "SableOS will remain installed.",
)
require(
    "tests/systemui/device/r9_identity_audit.sh",
    "R9_SYSTEM_IDENTITY_AUDIT=PASS_READ_ONLY",
    "android:string/android_system_label",
    "android:string/adb_active_notification_title",
)

# WS7: canonical preparation/qualification must carry the cohesion layers.
require(
    "build/panther/prepare-r8-final-ui.sh",
    "apply_r9_settings_cohesion.py",
    "apply_r9_launcher_cohesion.py",
    "R9_SETTINGS_COHESION=PASS",
    "R9_LAUNCHER_COHESION=PASS",
)
require(
    "build/gates/r8-final-product-composition.sh",
    "--allow-settings-untracked",
    "--allow-settings-modified",
    "R9_SETTINGS_COHESION_SOURCE=PASS",
    "R9_LAUNCHER_COHESION_SOURCE=PASS",
)
require(
    "build/check-repo-layout.sh",
    "R9_LAUNCHER_APPEARANCE_PROVIDER=PASS_RETIRED",
    "R9_SYSTEM_COHESION_LAYOUT=PASS",
    "apply_r9_settings_cohesion.py",
    "apply_r9_launcher_cohesion.py",
)

if failures:
    print("R9_SYSTEM_COHESION_CONTRACT=FAIL")
    for failure in failures:
        print(f"FAILURE={failure}")
    raise SystemExit(1)

print("R9_WS0_REJECTED_CANDIDATE_CONTRACT=PASS")
print("R9_SYSTEM_APPEARANCE_AUTHORITY=PASS_SETTINGS_HOSTED")
print("R9_LAUNCHER_GLOBAL_APPEARANCE_OWNERSHIP=PASS_RETIRED")
print("R9_SABLE_NATIVE_LAUNCHER_ESCAPE=PASS_SOURCE_BLOCKED")
print("R9_SABLE_SETTINGS_TOP_LEVEL=PASS_SOURCE")
print("R9_SYSTEMUI_APPEARANCE=PASS_SOURCE")
print("R9_READER_APPEARANCE=PASS_SOURCE")
print("R9_PLATFORM_SURFACE_CLASSIFICATION=PASS")
print("R9_SABLE_OWNED_BRANDING_CONTRACT=PASS")
print("R9_INTENTIONAL_UPSTREAM_BOUNDARY=PASS")
print("R9_WS6_SOURCE_AUDIT=PASS")
print("R9_WS7_INTEGRATION_CONTRACT=PASS")
print("R9_PHYSICAL_ACCEPTANCE=REQUIRED_FRESH_PANTHER")
print("R9_SYSTEM_COHESION_CONTRACT=PASS")
