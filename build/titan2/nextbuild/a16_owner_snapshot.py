#!/usr/bin/env python3
"""Read-only, bounded snapshot of existing Android16 native owner code.

Targets come from the pinned 26 Q25 patch diff headers plus explicit global
input-policy owner. No mutation, build, Git, network, device, mount or flash.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[3]
PATCH_ROOT = ROOT / "build/titan2/q25-onepass/patches/framework"
MANIFEST = ROOT / "build/titan2/q25-onepass/PATCH_MANIFEST_OWNER_RECOVERY_V1.json"
ALLOWED = ("frameworks/base", "packages/apps/Settings", "packages/apps/Dialer",
           "packages/apps/DocumentsUI", "packages/apps/Jelly", "packages/apps/SetupWizard")
EXTRA = ("frameworks/base/services/core/java/com/android/server/policy/PhoneWindowManager.java",)
DIFF = re.compile(r"^diff --git a/(\S+) b/(\S+)$", re.MULTILINE)
MAX_PATCH = 3_000_000
MAX_MEMBER = 2_000_000
MAX_TOTAL = 25_000_000


def safe(path: str) -> bool:
    p = PurePosixPath(path)
    return bool(p.parts) and not p.is_absolute() and ".." not in p.parts and "\\" not in path


def requested_paths(patch_root: Path, manifest: Path) -> list[str]:
    payload = json.loads(manifest.read_text(encoding="utf-8"))
    if len(payload.get("patches", [])) != 26:
        raise ValueError("expected the exact 26 Q25 owner patch entries")
    wanted = set(EXTRA)
    for patch in payload["patches"]:
        module = patch["module"]
        rel = patch["file"]
        if module not in ALLOWED or not safe(rel) or not rel.startswith(module + "/"):
            raise ValueError("unsafe or unexpected patch owner")
        source = patch_root / rel
        if source.is_symlink() or not source.is_file() or source.stat().st_size > MAX_PATCH:
            raise ValueError("patch unavailable or too large: " + rel)
        for before, after in DIFF.findall(source.read_text(encoding="utf-8")):
            if before != after or not safe(before):
                raise ValueError("unsafe patch header")
            full = module + "/" + before
            if not safe(full):
                raise ValueError("unsafe native owner target")
            wanted.add(full)
    return sorted(wanted)


def scan(android: Path, wanted: list[str]) -> tuple[list[dict], list[str]]:
    found, missing = [], []
    total = 0
    android = android.resolve(strict=True)
    for rel in wanted:
        if not safe(rel) or not any(rel.startswith(m + "/") for m in ALLOWED):
            raise ValueError("owner outside allowlist")
        child = android
        for segment in PurePosixPath(rel).parts:
            child = child / segment
            if child.is_symlink():
                raise ValueError("symlink in owner path: " + rel)
        if not child.is_file():
            missing.append(rel)
            continue
        count = child.stat().st_size
        total += count
        if count > MAX_MEMBER or total > MAX_TOTAL:
            raise ValueError("native source size limit exceeded")
        found.append({"path": rel, "size": count,
                      "sha256": hashlib.sha256(child.read_bytes()).hexdigest()})
    return found, missing


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--android-root", required=True, type=Path)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--plan", action="store_true")
    group.add_argument("--collect", action="store_true")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    if args.collect and args.out is None:
        parser.error("--collect requires --out")
    if args.plan and args.out is not None:
        parser.error("--plan must not specify --out")
    try:
        wanted = requested_paths(PATCH_ROOT, MANIFEST)
        found, missing = scan(args.android_root, wanted)
        report = {"schema": "TB2_Q25_A16_OWNER_SNAPSHOT_V1",
                  "mode": "collect" if args.collect else "plan",
                  "requested": len(wanted), "found": found, "missing": missing,
                  "source_mutation": False, "device_contact": False, "build": False}
        print("TB2_A16_NATIVE_OWNER_FOUND=" + str(len(found)))
        print("TB2_A16_NATIVE_OWNER_MISSING=" + str(len(missing)))
        if args.collect:
            output = args.out.resolve(strict=False)
            if output.is_relative_to(args.android_root.resolve()) or output.is_relative_to(ROOT):
                raise ValueError("output must be outside Android and Sable source trees")
            if output.exists() or not output.parent.is_dir() or output.suffix != ".zip":
                raise ValueError("out must be a new .zip under an existing directory")
            with zipfile.ZipFile(output, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as out:
                for entry in found:
                    out.write(args.android_root / entry["path"], "android/" + entry["path"])
                out.writestr("OWNER_SNAPSHOT.json", json.dumps(report, indent=2, sort_keys=True))
            print("TB2_A16_NATIVE_OWNER_ZIP=" + str(output))
        else:
            print(json.dumps(report, indent=2, sort_keys=True))
        return 0
    except (OSError, ValueError, KeyError, TypeError, UnicodeError, json.JSONDecodeError) as e:
        print("TB2_A16_OWNER_SNAPSHOT=HOLD_" + type(e).__name__ + " " + str(e), file=sys.stderr)
        return 78


if __name__ == "__main__":
    raise SystemExit(main())
