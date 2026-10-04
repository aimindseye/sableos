#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FAILURES: list[str] = []


def read(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        FAILURES.append(f"missing_file={rel}")
        return ""
    return path.read_text(encoding="utf-8")


def require(rel: str, *tokens: str) -> None:
    value = read(rel)
    for token in tokens:
        if token not in value:
            FAILURES.append(f"missing_token={rel}:{token}")


def forbid(rel: str, *tokens: str) -> None:
    value = read(rel)
    for token in tokens:
        if token in value:
            FAILURES.append(f"forbidden_token={rel}:{token}")


BUILD = "apps/r8/android/messages/build.gradle.kts"
MAIN = "apps/r8/android/messages/src/main/java/org/sableos/messages/MainActivity.kt"
MODEL = "apps/r8/android/messages/src/main/java/org/sableos/messages/MessagesInteractionModel.kt"
QUALIFIER = "build/panther/qualify-r9-standalone-messages.sh"

require(
    BUILD,
    "allWarningsAsErrors.set(true)",
    'config.setFrom(rootProject.file("config/detekt.yml"))',
    "ignoreFailures = false",
    "ignoreFailures.set(false)",
)

require(
    MAIN,
    '@file:Suppress("FunctionNaming")',
    "private const val VISIBLE_MESSAGE_COUNT = 3",
    "private const val ACTION_GRID_COLUMNS = 3",
    "private fun resolveMessagesKeyAction(",
    "private fun shortcutKeyAction(",
    "private fun interactionKeyAction(",
    "private fun enterKeyAction(",
    "private fun LatestMessages(",
    "private fun ConversationListControls(",
)
forbid(
    MAIN,
    '@file:Suppress("LongMethod"',
    '@file:Suppress("CyclomaticComplexMethod"',
    '@file:Suppress("MagicNumber"',
    '@file:Suppress("ReturnCount"',
    '@Suppress("LongMethod")',
    '@Suppress("CyclomaticComplexMethod")',
    '@Suppress("MagicNumber")',
    '@Suppress("ReturnCount")',
)

require(
    MODEL,
    "private fun reduceTimeline(",
    "private fun reduceHistory(",
    "private fun reduceConversationList(",
    "private fun reduceComposerInput(",
    "private fun reduceComposerUi(",
    "private fun reduceMessageActions(",
    "private fun reduceAttachments(",
    "private fun reduceProviderHandoff(",
    "private fun reducePrivacy(",
)
forbid(
    MODEL,
    '@file:Suppress(',
    '@Suppress("LongMethod")',
    '@Suppress("CyclomaticComplexMethod")',
    '@Suppress("MagicNumber")',
    '@Suppress("ReturnCount")',
)

require(
    QUALIFIER,
    "===== R9 STANDALONE MESSAGES QUALITY QUALIFICATION =====",
    ":messages:detekt",
    ":messages:ktlintCheck",
    ":messages:compileDebugKotlin",
    ":messages:testDebugUnitTest",
    ":messages:lintDebug",
    ":messages:assembleDebug",
    "--dependency-verification=strict",
    "NETWORK_FETCH_AUTHORIZED=NO",
    "DEVICE_CONTACT_AUTHORIZED=NO",
    "FLASH_AUTHORIZED=NO",
    "R9_STANDALONE_MESSAGES_DEVICE_RUNTIME_VALIDATED=NO",
    "R9_STANDALONE_MESSAGES_QUALIFICATION=PASS",
)
forbid(
    QUALIFIER,
    ":hub:",
    "adb ",
    "fastboot ",
)

if FAILURES:
    print("R9_STANDALONE_MESSAGES_QUALITY_CONTRACT=FAIL")
    for failure in FAILURES:
        print(f"FAILURE={failure}")
    raise SystemExit(1)

print("R9_STANDALONE_MESSAGES_QUALITY_POLICY=PASS_FAIL_CLOSED")
print("R9_STANDALONE_MESSAGES_COMPOSE_NAMING=PASS_BOUNDED_FILE_SUPPRESSION")
print("R9_STANDALONE_MESSAGES_REDUCER=PASS_DECOMPOSED")
print("R9_STANDALONE_MESSAGES_KEY_HANDLING=PASS_DECOMPOSED")
print("R9_STANDALONE_MESSAGES_QUALIFIER=PASS_MODULE_EXPLICIT")
print("R9_STANDALONE_MESSAGES_QUALITY_CONTRACT=PASS")
