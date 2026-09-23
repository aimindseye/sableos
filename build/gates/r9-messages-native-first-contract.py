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


HUB = "apps/r8/android/hub"
HUB_KT = f"{HUB}/src/main/java/org/sableos/hub"

require(
    f"{HUB}/src/main/AndroidManifest.xml",
    'android.permission.READ_SMS',
    'android.permission.SEND_SMS',
    'android.permission.READ_CONTACTS',
    'android:authorities="org.sableos.appearance"',
    'android:name=".MainActivity"',
)
forbid(
    f"{HUB}/src/main/AndroidManifest.xml",
    'android.permission.INTERNET',
    '.web.',
)

require(
    f"{HUB_KT}/MainActivity.kt",
    "LaunchedEffect(refreshGeneration)",
    "withContext(Dispatchers.IO)",
    "repository.snapshot()",
    "SableGlobalTheme(window = window)",
)
forbid(
    f"{HUB_KT}/MainActivity.kt",
    "ProviderCapsuleLauncher",
    "HubProviderCatalog",
    "createRequestRoleIntent",
)

require(
    f"{HUB_KT}/ui/HubScreen.kt",
    "HubPivot.Messages",
    "HubPivot.People",
    'label = { Text("Search conversations") }',
    "MessageBubble(",
    "LazyColumn(",
    "items = conversations.take(MAX_VISIBLE_CONVERSATIONS)",
    "items = people.take(MAX_VISIBLE_PEOPLE)",
    "items = messages",
    'text = "MMS / attachment"',
    "MAX_VISIBLE_CONVERSATIONS",
    "MAX_VISIBLE_THREAD_MESSAGES",
    "MAX_VISIBLE_PEOPLE",
)
forbid(
    f"{HUB_KT}/ui/HubScreen.kt",
    "HubPivot.All",
    "HubPivot.Services",
    "ProviderCapabilityClass",
    "HubProvider",
    "Private web session",
    "private, isolated web sessions",
    "RCS",
)

forbid(
    f"{HUB_KT}/HubModels.kt",
    "ProviderCapabilityClass",
    "HubProvider",
    "HubProviderCatalog",
    "WEB_SESSION",
)

require(
    f"{HUB_KT}/HubRepository.kt",
    "RoleManager.ROLE_SMS",
    "fun sendSms(",
    "fun openAndroidMessaging(",
    "Intent.CATEGORY_APP_MESSAGING",
    "Telephony.Sms.CONTENT_URI",
)
forbid(
    f"{HUB_KT}/HubRepository.kt",
    "createRequestRoleIntent",
    "SMS_DELIVER_ACTION",
    "WAP_PUSH_DELIVER_ACTION",
)

capsule = ROOT / HUB_KT / "web/ProviderCapsuleActivity.kt"
if capsule.exists():
    failures.append(
        "retired_provider_capsule_present="
        + str(capsule.relative_to(ROOT))
    )

require(
    "src/android/packages/apps/SableStart/src/com/sable/start/platform/LauncherAppsRepository.kt",
    'GRAPHENE_MESSAGING_PACKAGE = "com.android.messaging"',
)
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_messaging_visibility.py",
    "STANDALONE_SABLE_LAUNCHER_PRESENTATION",
    "R9_GRAPHENE_MESSAGING_ROLE=RETAINED_SMS_MMS_TRANSPORT",
)
require(
    "tests/systemui/device/r9_final_ui_runtime_audit.sh",
    "R9_FINAL_UI_PROVIDER_CAPSULES=PASS_RETIRED",
    "R9_FINAL_UI_SABLE_MESSAGES_INTERNET_PERMISSION=PASS_ABSENT",
    "R9_FINAL_UI_SMS_ROLE=PASS_GRAPHENE_MESSAGING",
)
require(
    "docs/SABLE_FLOW_AND_HUB_PRODUCT_PLAN.md",
    "Installed-app integration before embedded web emulation.",
    "installed-app-first",
    "no embedded provider WebView clients",
)
require(
    "docs/adr/0007-core-product-hub-aod-agent-and-aosp-boundary.md",
    "Embedded WhatsApp/Instagram/Messenger/LinkedIn WebViews are retired",
    "standalone SableLauncher",
)

if failures:
    print("R9_MESSAGES_NATIVE_FIRST_CONTRACT=FAIL")
    for failure in failures:
        print(f"FAILURE={failure}")
    raise SystemExit(1)

print("R9_SABLE_MESSAGES_SURFACE=PASS_MESSAGES_PEOPLE_NATIVE_FIRST")
print("R9_SABLE_MESSAGES_SNAPSHOT=PASS_OFF_MAIN")
print("R9_SABLE_MESSAGES_SEARCH=PASS_LOCAL_CONVERSATIONS")
print("R9_SABLE_MESSAGES_CONVERSATION_UI=PASS_BOUNDED_CHAT_BUBBLES")
print("R9_SABLE_MESSAGES_LARGE_LIST_RENDERING=PASS_LAZY")
print("R9_SABLE_MESSAGES_MMS=PASS_CONTEXTUAL_SYSTEM_HANDOFF")
print("R9_SABLE_MESSAGES_RCS_CLAIM=PASS_ABSENT")
print("R9_SABLE_MESSAGES_WEB_CAPSULES=PASS_RETIRED")
print("R9_SABLE_MESSAGES_INTERNET_PERMISSION=PASS_ABSENT")
print("R9_SOCIAL_INTEGRATION_POLICY=PASS_INSTALLED_APP_FIRST")
print("R9_GRAPHENE_MESSAGING_TRANSPORT_BOUNDARY=PASS_RETAINED")
print("R9_MESSAGES_NATIVE_FIRST_CONTRACT=PASS")
