#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import sys
from datetime import datetime, timezone


def sha256_file(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        while True:
            block = fp.read(4 * 1024 * 1024)
            if not block:
                break
            h.update(block)
    return h.hexdigest()


def registry_path(root: pathlib.Path, device: str, release: str, source: str) -> pathlib.Path:
    return root / device / release / f"{source}.json"


def register(args: argparse.Namespace) -> int:
    tf = pathlib.Path(args.target_files).resolve()
    ai = pathlib.Path(args.android_info).resolve()
    if not tf.is_file():
        print(f"SABLE_ARTIFACT_REGISTER=FAIL_TARGET_FILES_MISSING path={tf}", file=sys.stderr)
        return 2
    if not ai.is_file():
        print(f"SABLE_ARTIFACT_REGISTER=FAIL_ANDROID_INFO_MISSING path={ai}", file=sys.stderr)
        return 2

    actual = sha256_file(tf)
    print(f"TARGET_FILES={tf}")
    print(f"EXPECTED_TARGET_FILES_SHA256={args.sha256}")
    print(f"ACTUAL_TARGET_FILES_SHA256={actual}")
    if actual != args.sha256:
        print("SABLE_ARTIFACT_REGISTER=FAIL_SHA256")
        return 3

    root = pathlib.Path(args.registry_root).resolve()
    path = registry_path(root, args.device, args.release, args.build_source)
    path.parent.mkdir(parents=True, exist_ok=True)

    doc = {
        "schema": 1,
        "device": args.device,
        "release": args.release,
        "build_source": args.build_source,
        "target_files": str(tf),
        "target_files_sha256": actual,
        "android_info": str(ai),
        "android_info_sha256": sha256_file(ai),
        "out_dir": str(pathlib.Path(args.out_dir).resolve()) if args.out_dir else None,
        "build_evidence_dir": str(pathlib.Path(args.build_evidence_dir).resolve()) if args.build_evidence_dir else None,
        "registered_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

    if path.exists() and not args.replace:
        existing = json.loads(path.read_text(encoding="utf-8"))
        comparable = {
            key: doc[key]
            for key in (
                "schema",
                "device",
                "release",
                "build_source",
                "target_files",
                "target_files_sha256",
                "android_info",
                "android_info_sha256",
                "out_dir",
                "build_evidence_dir",
            )
        }
        existing_comparable = {key: existing.get(key) for key in comparable}
        if existing_comparable == comparable:
            print(f"ARTIFACT_MANIFEST={path}")
            print("SABLE_ARTIFACT_REGISTER=PASS_ALREADY_REGISTERED")
            return 0
        print(f"SABLE_ARTIFACT_REGISTER=FAIL_ALREADY_EXISTS_DIFFERENT path={path}")
        return 4

    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(doc, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(path)

    print(f"ARTIFACT_MANIFEST={path}")
    print("SABLE_ARTIFACT_REGISTER=PASS")
    return 0


def show(args: argparse.Namespace) -> int:
    path = registry_path(
        pathlib.Path(args.registry_root).resolve(),
        args.device,
        args.release,
        args.build_source,
    )
    if not path.is_file():
        print(f"SABLE_ARTIFACT_MANIFEST=NOT_FOUND path={path}", file=sys.stderr)
        return 2
    print(path.read_text(encoding="utf-8"), end="")
    return 0


def field(args: argparse.Namespace) -> int:
    path = registry_path(
        pathlib.Path(args.registry_root).resolve(),
        args.device,
        args.release,
        args.build_source,
    )
    if not path.is_file():
        return 2
    doc = json.loads(path.read_text(encoding="utf-8"))
    value = doc.get(args.field)
    if value is None:
        return 3
    print(value)
    return 0


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser()
    p.add_argument(
        "--registry-root",
        default="/srv/data/sable-build/release-registry",
    )
    sub = p.add_subparsers(dest="command", required=True)

    r = sub.add_parser("register")
    r.add_argument("--device", required=True)
    r.add_argument("--release", required=True)
    r.add_argument("--build-source", required=True)
    r.add_argument("--target-files", required=True)
    r.add_argument("--sha256", required=True)
    r.add_argument("--android-info", required=True)
    r.add_argument("--out-dir")
    r.add_argument("--build-evidence-dir")
    r.add_argument("--replace", action="store_true")

    s = sub.add_parser("show")
    s.add_argument("--device", required=True)
    s.add_argument("--release", required=True)
    s.add_argument("--build-source", required=True)

    f = sub.add_parser("field")
    f.add_argument("--device", required=True)
    f.add_argument("--release", required=True)
    f.add_argument("--build-source", required=True)
    f.add_argument("--field", required=True)
    return p


def main() -> int:
    args = parser().parse_args()
    if args.command == "register":
        return register(args)
    if args.command == "show":
        return show(args)
    if args.command == "field":
        return field(args)
    return 64


if __name__ == "__main__":
    raise SystemExit(main())
