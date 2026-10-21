#!/usr/bin/env python3
"""TB2 Hub source seams; static safety check, not a runtime/feature admission."""
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
HUB = Path("apps/r8/android/hub/src/main")
KOTLIN = HUB / "java/org/sableos/hub"

# Test actual post-C3B source owners, not historical implementation spellings.
# These checks are fail-closed if an expected source owner disappears.
REQUIRED: dict[Path, tuple[str, ...]] = {
    HUB / "AndroidManifest.xml": (
        "android.permission.BIND_NOTIFICATION_LISTENER_SERVICE",
        "android.service.notification.NotificationListenerService",
    ),
    KOTLIN / "ConnectedAppPolicy.kt": (
        "data class ConnectedAppKey(",
        "val packageName: String",
        "val userSerial: Long",
        "includeInMessages",
        "allowQuickReply",
    ),
    KOTLIN / "ConnectedAppsInventory.kt": (
        "LauncherApps",
        "getActivityList(null, profile.user)",
        "userSerial = serial",
        "launcherApps.startMainActivity(",
    ),
    KOTLIN / "platform/ProfileDirectory.kt": (
        "userManager.userProfiles",
        "userManager.isQuietModeEnabled(user)",
        "userManager.isUserUnlocked(user)",
        "fun liveSerials(): Set<Long>",
    ),
    KOTLIN / "policy/HubHistoryBounds.kt": (
        "const val MAX_RECORDS_TOTAL = 1_200",
        "const val MAX_RECORDS_PER_SOURCE = 300",
        "const val MAX_RETENTION_DAYS = 30",
        "policy?.includeInMessages == true",
        "liveUserSerials",
        "ConnectedNotificationRetention.shouldKeep(record, policy.retention, nowMillis)",
        ".take(MAX_RECORDS_TOTAL)",
    ),
    KOTLIN / "ConnectedNotificationHistoryStore.kt": (
        "SQLiteOpenHelper",
        "ConnectedHistorySchema.VERSION",
        "const val VERSION = 3",
        "HubHistoryBounds.retain(",
        "liveUserSerials = runCatching { profiles.liveSerials() }.getOrNull()",
        "deleteRecordsExcept(",
        "fun appendLocalReply(",
    ),
    KOTLIN / "notifications/ConnectedReplyRegistry.kt": (
        "RemoteInput.addResultsToIntent(",
        "handle.pendingIntent.send(",
        "requiresUnlock(",
        "profileLocked = profile?.locked ?: true",
    ),
    KOTLIN / "notifications/SableNotificationListenerService.kt": (
        "NotificationListenerService",
        "policy?.includeInMessages == true",
        "ConnectedReplyRegistry.remove(notificationKey)",
    ),
    KOTLIN / "HubRepository.kt": (
        "ConnectedReplyRegistry.send(",
        "private fun sourcePrivacy(",
        "profileLocked = profile?.locked ?: true",
    ),
}

# Notifications must use Android's generic listener; no provider-specific
# messaging whitelist/credentials/database access may slip into Hub sources.
FORBIDDEN_PROVIDER_PACKAGES = (
    "com.whatsapp",
    "org.thoughtcrime.securesms",
    "org.telegram.messenger",
    "com.linkedin.android",
)
MAX_FILE_BYTES = 1_048_576
MAX_SOURCE_FILES = 512


def _read(path: Path) -> str:
    if not path.is_file() or path.is_symlink():
        raise ValueError("missing_or_symlink")
    if path.stat().st_size > MAX_FILE_BYTES:
        raise ValueError("oversize_source")
    return path.read_text(encoding="utf-8")


def evaluate(root: Path) -> list[str]:
    """Only inspect bounded Hub source files, never the Android build outputs."""
    errors: list[str] = []
    for rel, tokens in REQUIRED.items():
        try:
            content = _read(root / rel)
        except (OSError, UnicodeError, ValueError) as exc:
            errors.append(f"source={rel} reason={type(exc).__name__}")
            continue
        for token in tokens:
            if token not in content:
                errors.append(f"source={rel} missing={token!r}")

    source_root = root / HUB
    if not source_root.is_dir():
        errors.append(f"missing_source_root={HUB}")
        return errors

    sources = sorted(
        (p for p in source_root.rglob("*") if p.suffix in (".kt", ".java", ".xml")),
        key=lambda path: str(path),
    )
    if len(sources) > MAX_SOURCE_FILES:
        errors.append(f"too_many_source_files={len(sources)}")
        return errors
    for path in sources:
        try:
            content = _read(path)
        except (OSError, UnicodeError, ValueError) as exc:
            errors.append(f"unreadable_source={path.relative_to(root)} reason={type(exc).__name__}")
            continue
        for package in FORBIDDEN_PROVIDER_PACKAGES:
            if package in content:
                errors.append(f"provider_specific_package={package} file={path.relative_to(root)}")
    return errors


def main() -> int:
    errors = evaluate(ROOT)
    if errors:
        for error in errors:
            print(f"TB2_HUB_SOURCE_FAIL: {error}", file=sys.stderr)
        print(f"TB2_HUB_SOURCE_CONTRACT=FAIL count={len(errors)}")
        return 1
    print("TB2_HUB_SOURCE_CONTRACT=PASS_STATIC_SOURCE_BOUND")
    print("TB2_HUB_HISTORY=PASS_BOUNDED_1200_TOTAL_300_PER_SOURCE_30_DAYS_STATIC")
    print("TB2_HUB_PROFILE=PASS_USER_SERIAL_AND_LOCK_POLICY_SOURCE")
    print("TB2_HUB_REMOTE_INPUT=PASS_SOURCE_GUARDED_NOT_RUNTIME")
    print("TB2_HUB_PROVIDER_PACKAGES=PASS_NO_HARDCODED_WHITELIST")
    print("TB2_HUB_Q25_RUNTIME_AND_SMS_ROLE=OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
