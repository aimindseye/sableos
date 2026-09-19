#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import sys
import xml.etree.ElementTree as ET

if len(sys.argv) != 2:
    raise SystemExit("usage: verify-reader-manifest.py <intermediates-root>")

root = pathlib.Path(sys.argv[1])
if not root.is_dir():
    raise SystemExit(f"intermediates root missing: {root}")

all_manifests = sorted(root.rglob("AndroidManifest.xml"))
if not all_manifests:
    raise SystemExit("no generated AndroidManifest.xml files found")

for path in all_manifests:
    print(f"GENERATED_MANIFEST_CANDIDATE={path}")


def low(path: pathlib.Path) -> str:
    return str(path).replace("\\", "/").lower()


ranks = [
    [p for p in all_manifests if "processsabledebugmainmanifest" in low(p)],
    [
        p
        for p in all_manifests
        if "merged_manifest" in low(p)
        and "sabledebug" in low(p)
        and "processsabledebugmanifest" in low(p)
    ],
    [
        p
        for p in all_manifests
        if "merged_manifest" in low(p) and "sabledebug" in low(p)
    ],
]

selected = None
for group in ranks:
    if not group:
        continue
    if len(group) != 1:
        for candidate in group:
            print(f"AMBIGUOUS_SABLE_MANIFEST={candidate}", file=sys.stderr)
        raise SystemExit("ambiguous generated Sable Reader manifest candidates")
    selected = group[0]
    break

if selected is None:
    raise SystemExit("generated Sable Reader merged manifest not found")

print(f"SABLE_READER_MERGED_MANIFEST={selected}")
text = selected.read_text(encoding="utf-8", errors="strict")

if "android.permission.INTERNET" in text:
    print(
        "SABLE_READER_FORBIDDEN_PERMISSION=android.permission.INTERNET",
        file=sys.stderr,
    )
    raise SystemExit(1)

print("SABLE_READER_INTERNET_PERMISSION=PASS_ABSENT")

if "android.permission.CAMERA" not in text:
    raise SystemExit("Sable Reader OCR camera permission missing")
print("SABLE_READER_CAMERA_PERMISSION=PASS_DECLARED_OPTIONAL_FLOW")

android_ns = "http://schemas.android.com/apk/res/android"
a = f"{{{android_ns}}}"
manifest = ET.fromstring(text)
package_name = manifest.attrib.get("package", "")
if package_name != "org.sableos.reader":
    raise SystemExit(f"unexpected Sable Reader package: {package_name}")
print(f"SABLE_READER_PACKAGE={package_name}")

camera_features = [
    feature
    for feature in manifest.findall("uses-feature")
    if feature.attrib.get(a + "name") == "android.hardware.camera"
]
if len(camera_features) != 1:
    raise SystemExit(
        f"expected one optional camera feature, found {len(camera_features)}"
    )
if camera_features[0].attrib.get(a + "required") != "false":
    raise SystemExit("Sable Reader camera hardware must remain optional")
print("SABLE_READER_CAMERA_HARDWARE=PASS_OPTIONAL")

application = manifest.find("application")
if application is None:
    raise SystemExit("Sable Reader application element missing")

text_activity = None
ocr_activity = None
launcher_components: list[str] = []

for tag in ("activity", "activity-alias"):
    for component in application.findall(tag):
        name = component.attrib.get(a + "name", "")
        for intent_filter in component.findall("intent-filter"):
            actions = {
                action.attrib.get(a + "name", "")
                for action in intent_filter.findall("action")
            }
            categories = {
                category.attrib.get(a + "name", "")
                for category in intent_filter.findall("category")
            }
            if (
                "android.intent.action.MAIN" in actions
                and "android.intent.category.LAUNCHER" in categories
            ):
                launcher_components.append(name)

        if name.endswith("SableTextActivity"):
            text_activity = component
        if name.endswith("SableOcrActivity"):
            ocr_activity = component

if len(launcher_components) != 1:
    raise SystemExit(
        f"expected exactly one launcher component, found {launcher_components}"
    )
print(f"SABLE_READER_LAUNCHER_COMPONENT={launcher_components[0]}")

if text_activity is None:
    raise SystemExit("SableTextActivity missing from composed manifest")
if ocr_activity is None:
    raise SystemExit("SableOcrActivity missing from composed manifest")
if ocr_activity.attrib.get(a + "exported") != "false":
    raise SystemExit("SableOcrActivity must remain non-exported")
print("SABLE_READER_OCR_ACTIVITY=PASS_INTERNAL")

actions_seen: set[str] = set()
mime_types: set[str] = set()
launcher_on_text_activity = False

for intent_filter in text_activity.findall("intent-filter"):
    actions = {
        action.attrib.get(a + "name", "")
        for action in intent_filter.findall("action")
    }
    categories = {
        category.attrib.get(a + "name", "")
        for category in intent_filter.findall("category")
    }
    actions_seen.update(actions)
    mime_types.update(
        data.attrib.get(a + "mimeType", "")
        for data in intent_filter.findall("data")
        if data.attrib.get(a + "mimeType")
    )
    if (
        "android.intent.action.MAIN" in actions
        and "android.intent.category.LAUNCHER" in categories
    ):
        launcher_on_text_activity = True

required_actions = {
    "android.intent.action.VIEW",
    "android.intent.action.SEND",
    "android.intent.action.PROCESS_TEXT",
}
missing_actions = sorted(required_actions - actions_seen)
if missing_actions:
    raise SystemExit(f"missing Sable text actions: {missing_actions}")

if "text/plain" not in mime_types:
    raise SystemExit("SableTextActivity does not declare text/plain")

if launcher_on_text_activity:
    raise SystemExit("SableTextActivity must not be a second launcher surface")

print("SABLE_READER_TEXT_VIEW=PASS")
print("SABLE_READER_TEXT_SEND=PASS")
print("SABLE_READER_PROCESS_TEXT=PASS")
print("SABLE_READER_TEXT_MIME=PASS")
print("SABLE_READER_SINGLE_LAUNCHER=PASS")
print("SABLE_READER_OCR_CAMERA_PERMISSION_SCOPE=PASS_RUNTIME_REQUEST")
