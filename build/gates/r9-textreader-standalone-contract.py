#!/usr/bin/env python3
"""R9 standalone Sable Text Reader source/product contract."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
failures: list[str] = []


def text(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        failures.append(f"missing_file={rel}")
        return ""
    return path.read_text(encoding="utf-8")


def require(rel: str, *needles: str) -> None:
    value = text(rel)
    for needle in needles:
        if needle not in value:
            failures.append(f"missing_token={rel}:{needle}")


def forbid(rel: str, *needles: str) -> None:
    value = text(rel)
    for needle in needles:
        if needle in value:
            failures.append(f"forbidden_token={rel}:{needle}")


require(
    "apps/r8/textreader/apply_sable_flavor.py",
    'EXPECTED_COMMIT = "50fca365baae9869264716569830690fb62029a7"',
    'applicationId = "org.sableos.textreader"',
    "SableTextReader-",
    "Sable Text Reader",
    "SableGlobalTheme(window = window)",
    "android.intent.action.VIEW",
    "SABLE_TEXT_READER_INTERNET_MERGE_RULE=PASS_REMOVE",
    "SABLE_TEXT_READER_INTERNET_PERMISSION=PASS_FINAL_APK_ABSENT_REQUIRED",
    "SABLE_TEXT_READER_TRANSLATION=PASS_RETIRED",
    "SABLE_TEXT_READER_OCR=PASS_CAMERA_GALLERY_LATIN_DEVANAGARI",
    "SABLE_TEXT_READER_VIEW_HANDLER=PASS_BOUNDED_LOCAL_TEXT",
    "SABLE_TEXT_READER_TEXT_INPUT=PASS_BOUNDED_2_MIB",
    "SABLE_TEXT_READER_TTS_NETWORK_VOICES=PASS_FILTERED",
)
require(
    "apps/r8/textreader/verify_sable_textreader.py",
    'EXPECTED_PACKAGE = "org.sableos.textreader"',
    'forbid(build, "com.google.mlkit:translate", "SABLE_TEXT_READER_TRANSLATION_DEPENDENCY")',
    "SABLE_TEXT_READER_INTERNET_MERGE_RULE=PASS_REMOVE",
    "SABLE_TEXT_READER_INTERNET_PERMISSION=PASS_FINAL_APK_ABSENT_REQUIRED",
    "SABLE_TEXT_READER_TRANSLATION=PASS_RETIRED",
    "SABLE_TEXT_READER_SINGLE_LAUNCHER=PASS",
    "SABLE_TEXT_READER_GLOBAL_APPEARANCE=PASS",
    "SABLE_TEXT_READER_APK_PACKAGE=PASS",
    "SABLE_TEXT_READER_APK_INTERNET_PERMISSION=PASS_ABSENT",
    "SABLE_TEXT_READER_APK_OFFLINE_BOUNDARY=PASS",
    "SABLE_TEXT_READER_TEXT_INPUT=PASS_BOUNDED_2_MIB",
    "SABLE_TEXT_READER_TTS_NETWORK_VOICES=PASS_FILTERED",
    "android.intent.action.SEND",
    "android.intent.action.PROCESS_TEXT",
    "downloadModelIfNeeded",
    "ProfessionalTranslationRow(",
)

require(
    "apps/r8/reader/apply_sable_flavor.py",
    "SABLE_READER_TEXTREADER_COMPOSITION=PASS_ABSENT",
    "SABLE_READER_PUBLICATION_FOCUS=PASS",
    "SABLE_READER_TEXTREADER_RUNTIME=PASS_ABSENT",
)
forbid(
    "apps/r8/reader/apply_sable_flavor.py",
    "SableTextActivity",
    "SableOcrActivity",
    "<vaachak-textreader-checkout>",
)

require(
    "build/gates/r8-no-stale-product-code.sh",
    "R8_GLOBAL_APPEARANCE_READER=PASS_PRODUCT_THEME_BRIDGE",
    "ProductReaderTheme.kt",
    "appearance = rememberGlobalSableAppearance(),",
)

require(
    "build/verify-reader-manifest.py",
    "SABLE_READER_CAMERA_PERMISSION=PASS_ABSENT",
    "SABLE_READER_TEXTREADER_COMPONENTS=PASS_ABSENT",
    "SABLE_READER_PUBLICATION_FOCUS=PASS",
)

require(
    "product/r8/panther/Android.bp",
    'name: "SableTextReader"',
    'apk: "prebuilt/SableTextReader.apk"',
)
require(
    "product/r8/panther/r8-product.mk",
    "SableTextReader",
)
require(
    "build/gates/verify-r8-vendor-sable-inventory.py",
    '"r8/prebuilt/SableTextReader.apk"',
    "R8_VENDOR_SABLE_CANONICAL_APK_COUNT=11",
)
require(
    "apps/r8/export-panther-app-bundle.sh",
    "SABLE_TEXTREADER_APK",
    "[org.sableos.textreader]=SableTextReader.apk",
    "org.sableos.textreader",
)
require(
    "build/panther/stage-r8-product-apps.sh",
    '"org.sableos.textreader": "SableTextReader.apk"',
    "SableTextReader.apk",
)
require(
    "build/gates/r8-final-target-files.sh",
    '"SableTextReader.apk": "org.sableos.textreader"',
    "[SableTextReader.apk]=org.sableos.textreader",
    "R9_SABLE_TEXT_READER_TARGET_FILES=PASS_PRESENT",
    "R9_SABLE_TEXT_READER_OCR_TARGET_FILES=PASS",
)
require(
    "build/panther/build-r8-final-ui.sh",
    "SableTextReader",
    "R9_SABLE_TEXT_READER_MODULE_BUILD=PASS",
)
require(
    "build/local-ci/run.sh",
    "R8_NO_STALE_WORKSPACE_INVENTORY_REQUIRED=NO",
    'python3 "$ROOT/apps/r8/textreader/apply_sable_flavor.py" "$work"',
    'python3 "$ROOT/apps/r8/textreader/verify_sable_textreader.py" "$work"',
    "SableTextReader-*.apk",
)
forbid(
    "build/local-ci/run.sh",
    'python3 "$ROOT/apps/r8/reader/apply_sable_flavor.py" "$reader" "$text"',
    "vaachak-textreader-reader",
)
require(
    "build/panther/qualify-r9-textreader.sh",
    "R8_NO_STALE_WORKSPACE_INVENTORY_REQUIRED=NO",
    "WORKSPACE_PRODUCT_INVENTORY_REQUIRED=NO_PRESTAGING",
)
require(
    "build/gates/r8-final-product-composition.sh",
    "R8_NO_STALE_WORKSPACE_INVENTORY_REQUIRED=YES",
)

require(
    "build/gates/r8-final-product-composition.sh",
    "===== R9 SABLE TEXT READER SOURCE CLOSURE =====",
    'grep -Fq "$needle" "$TEXTREADER_APPLIER"',
    'grep -Fq "$needle" "$TEXTREADER_VERIFY"',
    "SABLE_TEXT_READER_APK_INTERNET_PERMISSION=PASS_ABSENT",
    "SABLE_TEXT_READER_APK_OFFLINE_BOUNDARY=PASS",
    "R9_SABLE_TEXT_READER=PASS_SOURCE_POLICY_AND_PRODUCT_STAGED",
    "R9_READER_TEXTREADER_DECOMPOSITION=PASS",
)
forbid(
    "build/gates/r8-final-product-composition.sh",
    "R8_D2_READER_TEXT_ACCESSIBILITY_OCR=PASS_SOURCE_AND_PRODUCT_STAGED",
)

require(
    "build/panther/run-r8-release-candidate.sh",
    "===== SABLE TEXT READER =====",
    "SABLE_TEXTREADER_APK",
    "R9_SABLE_TEXT_READER_BUILD=PASS",
    "SOURCE-BOUND ELEVEN-APK BUNDLE",
    "R9_SOURCE_BOUND_ELEVEN_APK_FREEZE=PASS",
)
forbid(
    "build/panther/run-r8-release-candidate.sh",
    'apply_sable_flavor.py"     "$WORK/reader"     "$WORK/textreader"',
)

if failures:
    print("R9_TEXT_READER_STANDALONE_CONTRACT=FAIL")
    for failure in failures:
        print(f"FAILURE={failure}")
    raise SystemExit(1)

print("R9_SABLE_TEXT_READER_PRODUCT=PASS_STANDALONE")
print("R9_SABLE_READER_PRODUCT=PASS_PUBLICATION_ONLY")
print("R9_READER_TEXTREADER_DUPLICATION=PASS_ABSENT")
print("R9_TEXT_READER_STANDALONE_CONTRACT=PASS")
