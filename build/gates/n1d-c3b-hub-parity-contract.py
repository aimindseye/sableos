#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
errors = []

def read(path):
    p = ROOT / path
    if not p.is_file():
        errors.append(f"missing file: {path}")
        return ""
    return p.read_text(encoding="utf-8")

def require(path, *tokens):
    text = read(path)
    for token in tokens:
        if token not in text:
            errors.append(f"{path}: missing required token: {token}")
    return text

contract = require(
    "docs/titan2/N1D_C3B_HUB_PARITY.md",
    "C3B_HUB_PANTHER_V1_SEMANTICS_REQUIRED=YES",
    "C3B_HUB_CONNECTED_APPS=REQUIRED",
    "C3B_HUB_GENERIC_NOTIFICATION_ADAPTER=REQUIRED",
    "C3B_HUB_REMOTEINPUT_REPLY=REQUIRED",
    "C3B_HUB_OPEN_APP_FALLBACK=REQUIRED",
    "C3B_HUB_PACKAGE_USER_POLICY=REQUIRED",
    "C3B_HUB_LOCAL_BOUNDED_HISTORY=REQUIRED",
    "C3B_HUB_DYNAMIC_PROVIDER_DISCOVERY=REQUIRED",
    "C3B_HUB_PROVIDER_SPECIFIC_ALLOWLIST=NO",
    "C3B_HUB_PRIVATE_PROVIDER_PROTOCOLS=NO",
    "C3B_HUB_PROVIDER_CREDENTIALS=NO",
    "C3B_HUB_PRIVATE_DATABASE_SCRAPING=NO",
    "C3B_HUB_PROVIDER_WEBVIEWS=NO",
    "C3B_HUB_DEVICE_RUNTIME_VALIDATED=NO",
    "SABLE_MESSAGES_AND_SABLE_HUB_ARE_SEPARATE_PRODUCT_SURFACES=YES",
    "D4_MESSAGES_REPLACES_SABLE_HUB=NO",
    "D4_MESSAGES_WEAKENS_CONNECTED_APPS=NO",
)

require(
    "apps/r8/android/hub/src/main/AndroidManifest.xml",
    "android.permission.BIND_NOTIFICATION_LISTENER_SERVICE",
    "android.service.notification.NotificationListenerService",
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/ConnectedAppPolicy.kt",
    "packageName: String",
    "userSerial: Long",
    "includeInMessages",
    "allowQuickReply",
    "hideFromLauncher",
)
inventory = require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/ConnectedAppsInventory.kt",
    "LauncherApps",
    ".getActivityList(null, user)",
    "packageName = info.componentName.packageName",
    "userSerial = serial",
    "launcherApps.startMainActivity",
)
listener = require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/notifications/SableNotificationListenerService.kt",
    "NotificationListenerService",
    "packageName = sbn.packageName",
    "userSerial = serial",
    "policy?.includeInMessages == true",
    "Notification.EXTRA_MESSAGES",
    "Notification.EXTRA_MESSAGING_PERSON",
    "Notification.FLAG_GROUP_SUMMARY",
    "Notification.CATEGORY_MESSAGE",
    "allowQuickReply = policy.allowQuickReply",
    "action.remoteInputs",
    "input.allowFreeFormInput",
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/notifications/ConnectedReplyRegistry.kt",
    "RemoteInput.addResultsToIntent",
    "handle.pendingIntent.send",
    "Open the source app instead.",
    "Reply handed to the source app.",
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/ConnectedNotificationHistoryStore.kt",
    "SQLiteOpenHelper",
    "MAX_HISTORY_RECORDS = 1200",
    "normalized?.includeInMessages == true",
    "normalized.retention",
)
require(
    "apps/r8/android/hub/src/main/java/org/sableos/hub/HubRepository.kt",
    "ConnectedReplyRegistry.send",
    "appendLocalReply",
    "openConnectedApp",
)
adr = require(
    "docs/adr/0011-sable-hub-v1.md",
    "Signal notification ingestion",
    "WhatsApp notification ingestion/rendering",
    "LinkedIn notification ingestion",
    "Telegram installation works but account setup was not completed",
    "no provider-specific hard-coded allowlist is required",
)

provider_packages = (
    "com.whatsapp",
    "org.thoughtcrime.securesms",
    "org.telegram.messenger",
    "com.linkedin.android",
)
src = ROOT / "apps/r8/android/hub/src/main"
for p in src.rglob("*"):
    if p.is_file() and p.suffix in {".kt", ".java", ".xml"}:
        text = p.read_text(encoding="utf-8")
        for package in provider_packages:
            if package in text:
                errors.append(
                    f"{p.relative_to(ROOT)}: provider-specific package hard-coded: {package}"
                )

if errors:
    for error in errors:
        print("N1D_C3B_HUB_PARITY_FAIL:", error, file=sys.stderr)
    print(f"N1D_C3B_HUB_PARITY_CONTRACT=FAIL count={len(errors)}")
    sys.exit(1)

print("N1D_C3B_HUB_CANONICAL_SOURCE=PASS")
print("N1D_C3B_HUB_CONNECTED_APPS=PASS_GENERIC_PACKAGE_USER")
print("N1D_C3B_HUB_NOTIFICATION_ADAPTER=PASS_GENERIC")
print("N1D_C3B_HUB_REMOTEINPUT=PASS_SOURCE_AUTHORIZED")
print("N1D_C3B_HUB_OPEN_APP_FALLBACK=PASS")
print("N1D_C3B_HUB_HISTORY=PASS_LOCAL_BOUNDED")
print("N1D_C3B_HUB_PROVIDER_ALLOWLIST=PASS_ABSENT")
print("N1D_C3B_HUB_PANTHER_EVIDENCE_BINDING=PASS")
print("N1D_C3B_HUB_PARITY_CONTRACT=PASS")
