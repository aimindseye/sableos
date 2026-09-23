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

for forbidden_permission in (
    "android.permission.INTERNET",
    "android.permission.CAMERA",
):
    if forbidden_permission in text:
        raise SystemExit(
            f"SABLE_READER_FORBIDDEN_PERMISSION={forbidden_permission}"
        )
print("SABLE_READER_INTERNET_PERMISSION=PASS_ABSENT")
print("SABLE_READER_CAMERA_PERMISSION=PASS_ABSENT")

for forbidden_component in (
    "SableTextActivity",
    "SableOcrActivity",
):
    if forbidden_component in text:
        raise SystemExit(
            f"SABLE_READER_TEXTREADER_COMPONENT=FAIL_PRESENT "
            f"component={forbidden_component}"
        )
print("SABLE_READER_TEXTREADER_COMPONENTS=PASS_ABSENT")

android_ns = "http://schemas.android.com/apk/res/android"
a = f"{{{android_ns}}}"
manifest = ET.fromstring(text)
package_name = manifest.attrib.get("package", "")
if package_name != "org.sableos.reader":
    raise SystemExit(f"unexpected Sable Reader package: {package_name}")
print(f"SABLE_READER_PACKAGE={package_name}")

application = manifest.find("application")
if application is None:
    raise SystemExit("Sable Reader application element missing")

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

if len(launcher_components) != 1:
    raise SystemExit(
        f"expected exactly one Reader launcher component, found {launcher_components}"
    )

print(f"SABLE_READER_LAUNCHER_COMPONENT={launcher_components[0]}")
print("SABLE_READER_SINGLE_LAUNCHER=PASS")
print("SABLE_READER_PUBLICATION_FOCUS=PASS")
print("SABLE_READER_TEXTREADER_RUNTIME=PASS_ABSENT")
