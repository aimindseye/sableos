#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import sys

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

def low(p: pathlib.Path) -> str:
    return str(p).replace("\\", "/").lower()

ranks = [
    [p for p in all_manifests if "processsabledebugmainmanifest" in low(p)],
    [p for p in all_manifests if "merged_manifest" in low(p) and "sabledebug" in low(p) and "processsabledebugmanifest" in low(p)],
    [p for p in all_manifests if "merged_manifest" in low(p) and "sabledebug" in low(p)],
]

selected = None
for group in ranks:
    if not group:
        continue
    if len(group) != 1:
        for p in group:
            print(f"AMBIGUOUS_SABLE_MANIFEST={p}", file=sys.stderr)
        raise SystemExit("ambiguous generated Sable Reader manifest candidates")
    selected = group[0]
    break

if selected is None:
    raise SystemExit("generated Sable Reader merged manifest not found")

print(f"SABLE_READER_MERGED_MANIFEST={selected}")
text = selected.read_text(encoding="utf-8", errors="strict")
if "android.permission.INTERNET" in text:
    print("SABLE_READER_INTERNET_PERMISSION=FAIL", file=sys.stderr)
    raise SystemExit(1)

print("SABLE_READER_INTERNET_PERMISSION=PASS")
