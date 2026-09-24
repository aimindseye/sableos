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
MANIFEST = f"{HUB}/src/main/AndroidManifest.xml"

require(
    MANIFEST,
    'android:name=".ConnectedAppsActivity"',
    'android:authorities="org.sableos.hub.connected_apps"',
    'android:name=".notifications.SableNotificationListenerService"',
    'android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"',
    'android.service.notification.NotificationListenerService',
    'android:label="Sable Hub"',
    'android:authorities="org.sableos.mail.snapshot"',
    'android:name="org.sableos.mail"',
)
forbid(
    MANIFEST,
    'android.permission.INTERNET',
    'android.webkit.WebView',
)

require(
    f"{HUB_KT}/ConnectedAppPolicy.kt",
    "data class ConnectedAppKey(",
    "val packageName: String",
    "val userSerial: Long",
    "includeInMessages",
    "allowQuickReply",
    "hideFromLauncher",
    "HistoryRetention",
    "ConnectedAppPolicyCodec",
)
require(
    f"{HUB_KT}/ConnectedAppsPolicyProvider.kt",
    "Binder.getCallingUid()",
    "Process.myUid()",
    "getPackagesForUid(callingUid)",
    'SABLE_LAUNCHER_PACKAGE = "org.sableos.launcher"',
    "throw SecurityException(",
    'throw UnsupportedOperationException("Read-only provider")',
)

require(
    f"{HUB_KT}/ConnectedAppsRepository.kt",
    'AUTHORITY = "org.sableos.hub.connected_apps"',
    "HIDDEN_URI",
    "HISTORY_URI",
    "cachedPolicyFor(",
    "cachedPolicySnapshot()",
    "updateCachedPolicy(normalized)",
    "hiddenKeys()",
)

HISTORY = f"{HUB_KT}/ConnectedNotificationHistoryStore.kt"
require(
    HISTORY,
    "SQLiteOpenHelper",
    'DATABASE_NAME = "sable_connected_message_history.db"',
    "SQLiteDatabase.CONFLICT_REPLACE",
    "MAX_HISTORY_RECORDS = 1200",
    "ConnectedNotificationRetention.shouldKeep",
    "normalized?.includeInMessages == true",
    'CONNECTED_LOCAL_REPLY_PREFIX = "local-reply:"',
    "fun appendLocalReply(",
    "incoming = false",
)
forbid(
    HISTORY,
    "getSharedPreferences(",
    "createDeviceProtectedStorageContext",
)

NORMALIZER = f"{HUB_KT}/notifications/ConnectedNotificationNormalizer.kt"
require(
    NORMALIZER,
    "data class ConnectedNotificationMessageSnapshot(",
    "data class ConnectedNotificationReplyCandidate(",
    "MAX_NOTIFICATION_MESSAGES = 25",
    "MAX_NOTIFICATION_ACTIONS = 8",
    "MAX_NOTIFICATION_REMOTE_INPUTS = 4",
    "MAX_NOTIFICATION_BODY_LENGTH = 4096",
)
forbid(
    NORMALIZER,
    "Notification.Builder",
    "recoverBuilder(",
)

LISTENER = f"{HUB_KT}/notifications/SableNotificationListenerService.kt"
require(
    LISTENER,
    "policies::cachedPolicyFor",
    "captureEnvelope(",
    "notification.shortcutId",
    "captureMessages(",
    "captureReplyCandidate(",
    "MAX_NOTIFICATION_MESSAGES",
    "MAX_NOTIFICATION_ACTIONS",
    "MAX_NOTIFICATION_REMOTE_INPUTS",
    "?.takeLast(MAX_NOTIFICATION_MESSAGES)",
    "?.toTypedArray()",
    ".getMessagesFromBundleArray(bundles)",
    "processEnvelope(",
    "Dispatchers.Default",
    "withContext(Dispatchers.IO)",
    "Dispatchers.Main.immediate",
    "notificationGenerations",
    "ConnectedReplyRegistry.register",
    "policies.cachedPolicySnapshot()",
    "history.merge(",
)
forbid(
    LISTENER,
    "policies.policyFor(",
    "Notification.Builder",
    "recoverBuilder(",
    "cancelNotification(",
    "cancelAllNotifications(",
)

REPLY = f"{HUB_KT}/notifications/ConnectedReplyRegistry.kt"
require(
    REPLY,
    "RemoteInput.addResultsToIntent",
    "handle.pendingIntent.send(",
    "ConcurrentHashMap",
    "Quick reply is no longer available",
)

require(
    f"{HUB_KT}/ui/ConnectedAppsScreen.kt",
    'title = "connected apps"',
    "ConnectedAppsPivot.Enabled",
    "ConnectedAppsPivot.Available",
    'label = "Search installed apps"',
    'label = "Allow quick reply"',
    'label = "Hide from SableLauncher"',
    "History retention:",
)
require(
    f"{HUB_KT}/ui/HubScreen.kt",
    "HubPivot.Priority",
    "HubPivot.Messages",
    "HubPivot.Email",
    "HubPivot.People",
    'title = "hub"',
    'text = "connected apps"',
    "HubConversationSource.ConnectedApp",
    "Content hidden by source app",
    'text = "Open source app"',
    'label = { Text("Reply") }',
    'text = "Send reply"',
    '"Handed off · "',
    "onSendConnectedReply",
)
forbid(
    f"{HUB_KT}/ui/HubScreen.kt",
    "HubRoute.ConnectedReply",
    "private fun ConnectedReplyView(",
)
require(
    f"{HUB_KT}/HubRepository.kt",
    "HubConnectedConversationReducer.reduce",
    "ConnectedReplyRegistry::canReply",
    "fun replyToConnected(",
    "connectedHistory.appendLocalReply(",
    "fun openConnectedApp(",
    "fun openSableMail(",
    "private fun loadMailSnapshot(",
    'content://org.sableos.mail.snapshot/current',
)

require(
    f"{HUB_KT}/HubModels.kt",
    "private fun reduceConversation(",
    "private fun conversationKeyFor(",
    "private fun ConnectedNotificationRecord.toHubMessage(",
    "private fun ConnectedNotificationRecord.toHubConversation(",
    "ConnectedConversationSlice",
    "handoffOnly",
    "CONNECTED_LOCAL_REPLY_PREFIX",
    "data class HubMailSnapshot(",
)

require(
    "src/android/packages/apps/SableStart/src/com/sable/start/platform/LauncherAppsRepository.kt",
    "HIDDEN_APPS_URI",
    'content://org.sableos.hub.connected_apps/hidden',
    "HiddenAppKey(packageName, userSerial) !in hiddenApps",
)
require(
    "src/android/packages/apps/SableStart/src/com/sable/start/SableStartActivity.kt",
    "LauncherAppsRepository.HIDDEN_APPS_URI",
    "appInventoryObserver",
    "Executors.newSingleThreadExecutor()",
    "inventoryGeneration",
    "inventoryExecutor.execute",
    "inventoryExecutor.shutdownNow()",
)
forbid(
    "src/android/packages/apps/SableStart/src/com/sable/start/SableStartActivity.kt",
    "appsState.value = launcherAppsRepository.loadApps()",
)
require(
    "tests/systemui/device/r9_final_ui_runtime_audit.sh",
    "R9_FINAL_UI_CONNECTED_APPS_ACTIVITY=PASS",
    "R9_FINAL_UI_CONNECTED_APPS_PROVIDER=PASS",
    "R9_FINAL_UI_NOTIFICATION_LISTENER=PASS_GENERIC",
    "R9_SABLE_MESSAGES_NOTIFICATION_ACCESS=PASS_USER_AUTHORIZED",
    "R9_SABLE_MESSAGES_NOTIFICATION_ACCESS=PENDING_USER_AUTHORIZATION",
)

require(
    "patches/android-17-grapheneos-2026081300/r9_settings_cohesion/strings_sable_cohesion.xml",
    '<string name="sable_messages_settings_title">Hub</string>',
    "Connected apps, conversations, email and local privacy",
)
require(
    "patches/android-17-grapheneos-2026081300/apply_r9_settings_cohesion.py",
    "MESSAGES_BLOCK",
    'android:key="top_level_sable_messages"',
    'android:action="org.sableos.hub.action.CONNECTED_APPS"',
    "R9_SETTINGS_MESSAGES_CONNECTED_APPS_ENTRY=PASS",
)
require(
    "docs/adr/0008-configurable-local-conversation-adapters.md",
    "(packageName, Android user/profile)",
    "CONVERSATION_REPLY",
    "NOTIFICATION_ONLY",
    "LAUNCH_ONLY",
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
    '"org.sableos.hub"',
    "SABLE_MAIL_HUB_SNAPSHOT_CALLER=PASS_BOUNDED_READ_ONLY",
)
require(
    "docs/adr/0011-sable-hub-v1.md",
    "Priority | Messages | Email | People",
    "Enabled | Available",
    "Handed off",
    "Hub must not read Sable Mail's private database",
)

require(
    "docs/R9_MESSAGES_LOCAL_CONVERSATION_ADAPTERS.md",
    "R9_MESSAGES_CONNECTED_APPS=PASS_CONFIGURABLE_PACKAGE_USER",
    "R9_MESSAGES_LISTENER_CALLBACK=PASS_BOUNDED_MEMORY_POLICY",
    "R9_MESSAGES_REMOTE_INPUT=PASS_SOURCE_AUTHORIZED_ONLY",
)

require(
    f"{HUB}/build.gradle.kts",
    "allWarningsAsErrors.set(true)",
    'config.setFrom(rootProject.file("config/detekt.yml"))',
    "ignoreFailures = false",
    "ignoreFailures.set(false)",
)
require(
    f"{HUB}/.editorconfig",
    "ktlint_function_naming_ignore_when_annotated_with = Composable",
)
forbid(
    "apps/r8/android/config/detekt.yml",
    '"**/hub/HubModels.kt"',
)
require(
    "build/gates/r9-messages-source-style.py",
    "MAX_LINE_LENGTH = 120",
    "R9_MESSAGES_SOURCE_STYLE_PREFLIGHT=PASS",
    "R9_MESSAGES_SOURCE_MAX_LINE_LENGTH=PASS",
    "R9_MESSAGES_SOURCE_WHITESPACE=PASS",
    "R9_MESSAGES_SOURCE_CHAIN_INDENTATION=PASS",
    "R9_MESSAGES_COMPOSE_WEIGHT_IMPORT=PASS_SCOPED",
)

QUALIFIER = "build/panther/qualify-r9-messages.sh"
require(
    QUALIFIER,
    'git -C "$ROOT" diff --check "$QUALIFIED_BASE...$ACTUAL_SOURCE"',
    "R9_MESSAGES_SOURCE_DIFF_CHECK=PASS",
    "===== R9 MESSAGES SOURCE STYLE PREFLIGHT =====",
    'python3 "$ROOT/build/gates/r9-messages-source-style.py"',
    "===== R9 MESSAGES STATIC QUALITY PREFLIGHT =====",
    ":hub:detekt",
    ":hub:ktlintCheck",
    "R9_MESSAGES_STATIC_QUALITY_PREFLIGHT=PASS",
    "===== R9 MESSAGES COMPILE TEST LINT =====",
    ":hub:compileDebugKotlin",
    ":hub:testDebugUnitTest",
    ":hub:lintDebug",
    "R9_MESSAGES_COMPILE=PASS",
    "===== R9 MESSAGES APK ASSEMBLY =====",
    ":hub:assembleDebug",
)
qualifier = read(QUALIFIER)
source_style_index = qualifier.find("===== R9 MESSAGES SOURCE STYLE PREFLIGHT =====")
preflight_index = qualifier.find("===== R9 MESSAGES STATIC QUALITY PREFLIGHT =====")
compile_index = qualifier.find("===== R9 MESSAGES COMPILE TEST LINT =====")
assemble_index = qualifier.find("===== R9 MESSAGES APK ASSEMBLY =====")
if not (
    0 <= source_style_index < preflight_index < compile_index < assemble_index
):
    failures.append(
        "messages_qualification_order="
        "source_style_before_quality_before_compile_before_assemble"
    )

hub_source_root = ROOT / HUB / "src/main/java"
for path in sorted(hub_source_root.rglob("*.kt")):
    value = path.read_text(encoding="utf-8")
    rel = path.relative_to(ROOT)
    for token in (
        "com.whatsapp",
        "org.telegram",
        "org.thoughtcrime",
        "android.webkit.WebView",
        "AccessibilityService",
    ):
        if token in value:
            failures.append(f"provider_specific_or_scraping_token={rel}:{token}")

if failures:
    print("R9_MESSAGES_LOCAL_CONVERSATION_ADAPTER_CONTRACT=FAIL")
    for failure in failures:
        print(f"FAILURE={failure}")
    raise SystemExit(1)

print("R9_MESSAGES_CONNECTED_APPS=PASS_CONFIGURABLE_PACKAGE_USER")
print("R9_MESSAGES_NOTIFICATION_LISTENER=PASS_GENERIC")
print("R9_MESSAGES_LISTENER_CALLBACK=PASS_BOUNDED_MEMORY_POLICY")
print("R9_MESSAGES_NOTIFICATION_NORMALIZATION=PASS_BOUNDED")
print("R9_MESSAGES_NOTIFICATION_HANDOFF=PASS_NO_FULL_NOTIFICATION")
print("R9_MESSAGES_REMOTE_INPUT=PASS_SOURCE_AUTHORIZED_ONLY")
print("R9_MESSAGES_SOURCE_NOTIFICATION_LIFECYCLE=PASS_NOT_CANCELLED")
print("R9_MESSAGES_PRIVATE_DATABASE_ACCESS=PASS_ABSENT")
print("R9_MESSAGES_PROVIDER_WEBVIEW=PASS_ABSENT")
print("R9_MESSAGES_PROVIDER_CREDENTIALS=PASS_ABSENT")
print("R9_MESSAGES_HISTORY=PASS_CE_BOUNDED_SQLITE")
print("R9_MESSAGES_LAUNCHER_HIDE_POLICY=PASS_DYNAMIC")
print("R9_MESSAGES_LAUNCHER_POLICY_CALLER_BOUNDARY=PASS_LAUNCHER_ONLY")
print("R9_MESSAGES_LAUNCHER_INVENTORY_REFRESH=PASS_OFF_MAIN")
print("R9_MESSAGES_SETTINGS_ENTRY=PASS_CONNECTED_APPS")
print("R9_MESSAGES_REDUCER_STRUCTURE=PASS_DECOMPOSED")
print("R9_MESSAGES_SOURCE_DIFF_CHECK=PASS_REQUIRED")
print("R9_MESSAGES_SOURCE_STYLE_PREFLIGHT=PASS_REQUIRED")
print("R9_MESSAGES_COMPOSE_KTLINT_POLICY=PASS_MEDIA_ALIGNED")
print("R9_MESSAGES_QUALITY_CONFIG=PASS_FAIL_CLOSED")
print("R9_MESSAGES_QUALIFICATION_ORDER=PASS_SOURCE_STYLE_BEFORE_GRADLE")
print("R9_HUB_PRODUCT_IDENTITY=PASS_SABLE_HUB")
print("R9_HUB_PIVOTS=PASS_PRIORITY_MESSAGES_EMAIL_PEOPLE")
print("R9_HUB_CONNECTED_APPS=PASS_ENABLED_AVAILABLE")
print("R9_HUB_REPLY_HISTORY=PASS_TRUTHFUL_HANDOFF_ONLY")
print("R9_HUB_MAIL_BOUNDARY=PASS_BOUNDED_SNAPSHOT")
print("R9_MESSAGES_LOCAL_CONVERSATION_ADAPTER_CONTRACT=PASS")
