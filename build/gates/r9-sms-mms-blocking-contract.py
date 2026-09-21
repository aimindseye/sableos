#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
failures: list[str] = []


def read(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        failures.append(f"missing_file={rel}")
        return ""
    return path.read_text(encoding="utf-8")


def require(rel: str, *tokens: str) -> None:
    text = read(rel)
    for token in tokens:
        if token not in text:
            failures.append(f"missing_token={rel}:{token}")


def forbid_tree(rel: str, *tokens: str) -> None:
    root = ROOT / rel
    if not root.exists():
        failures.append(f"missing_tree={rel}")
        return
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix not in {".kt", ".java", ".xml"}:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for token in tokens:
            if token in text:
                failures.append(
                    f"forbidden_token={path.relative_to(ROOT)}:{token}"
                )


require(
    "docs/R9_SMS_MMS_BLOCKING_SPAM.md",
    "Android's platform blocked-number provider",
    "Graphene Messaging remains unmodified",
    "Automatic spam detection is a separate feature",
    "medium-to-high",
    "under the current architecture.",
    "Sable Hub must not request ownership",
    "WAP_PUSH_DELIVER",
    "R9_SMS_MMS_SPAM_CLASSIFICATION=DEFERRED_DEFAULT_SMS_INTEGRATION_REQUIRED",
)

require(
    "patches/android-17-grapheneos-2026081300/apply_r9_phone_contacts_presentation.py",
    'DIALER_HEAD = "6a629762cf425002d34ecf28596813babda7d751"',
    "DIALER_BLOCKING",
    "android.provider.BlockedNumberContract",
    "BlockedNumbers.COLUMN_ORIGINAL_NUMBER",
    "BlockedNumbers.COLUMN_E164_NUMBER",
    "ContentProviderOperation.newInsert(BlockedNumbers.CONTENT_URI)",
    "ContentProviderOperation.newDelete(BlockedNumbers.CONTENT_URI)",
    "FilteredNumberCompat.canCurrentUserOpenBlockSettings(this)",
    "FilteredNumberCompat.createManageBlockedNumbersIntent(this)",
    "R9_BLOCKED_NUMBER_PLATFORM_SUBSTRATE=PASS",
    "R9_BLOCKED_NUMBER_SETTINGS_UI=PASS",
    "R9_SMS_MMS_BLOCKING_OWNER=ANDROID_BLOCKED_NUMBER_PROVIDER",
    "R9_SMS_MMS_BLOCKING_MESSAGING_FORK_REQUIRED=NO",
)

require(
    "patches/android-17-grapheneos-2026081300/apply_r9_messaging_visibility.py",
    'MESSAGING_HEAD = "d125442740e85c8c630c6b3c1091046166b99187"',
    "R9_GRAPHENE_MESSAGING_PACKAGE_RETAINED=PASS_PREBUILT",
    "R9_GRAPHENE_MESSAGING_SOURCE_MUTATION=NONE",
)

require(
    "build/panther/prepare-r8-final-ui.sh",
    'python3 "$PHONE_CONTACTS" --source "$WS" verify',
    'python3 "$MESSAGING_VISIBILITY" --source "$WS" verify',
)

# Sable Hub can present messaging capabilities, but it must not pretend to be
# the default telephony SMS/MMS delivery owner.
forbid_tree(
    "apps/r8/android/hub",
    "android.provider.Telephony.SMS_DELIVER",
    "android.provider.Telephony.WAP_PUSH_DELIVER",
    "Telephony.Sms.Intents.SMS_DELIVER_ACTION",
    "Telephony.Sms.Intents.WAP_PUSH_DELIVER_ACTION",
    "BlockedNumberContract.BlockedNumbers",
)

if failures:
    print("R9_SMS_MMS_BLOCKING_CONTRACT=FAIL")
    for failure in failures:
        print(f"FAILURE={failure}")
    raise SystemExit(1)

print("R9_BLOCKED_NUMBER_PLATFORM_CONTRACT=PASS")
print("R9_BLOCKED_NUMBER_SETTINGS_CONTRACT=PASS")
print("R9_GRAPHENE_MESSAGING_BLOCKING_BOUNDARY=PASS")
print("R9_SABLE_HUB_SMS_DELIVERY_OWNERSHIP=PASS_ABSENT")
print("R9_SMS_MMS_SPAM_CLASSIFICATION=DEFERRED_DEFAULT_SMS_INTEGRATION_REQUIRED")
print("R9_SMS_MMS_BLOCKING_CONTRACT=PASS")
sys.exit(0)
