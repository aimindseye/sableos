#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import sys
import tempfile
from datetime import datetime, timezone

SCHEMA_VERSION = 2
ARTIFACT_KINDS = (
    "target-files",
    "full-device-images",
    "gsi-system-image",
    "system-product-bundle",
    "boot-recovery-bundle",
)
NAME_RE = re.compile(r"^[A-Za-z0-9._-]+$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


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


def parse_assignment(raw: str, what: str) -> tuple[str, str]:
    if "=" not in raw:
        raise ValueError(f"{what} must use NAME=VALUE form: {raw!r}")
    name, value = raw.split("=", 1)
    if not NAME_RE.fullmatch(name):
        raise ValueError(f"invalid {what} name: {name!r}")
    if not value:
        raise ValueError(f"empty {what} value for {name!r}")
    return name, value


def parse_assignments(items: list[str] | None, what: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for raw in items or []:
        name, value = parse_assignment(raw, what)
        if name in out:
            raise ValueError(f"duplicate {what} name: {name}")
        out[name] = value
    return out


def normalize_registration(args: argparse.Namespace) -> tuple[str, str, dict[str, pathlib.Path], dict[str, str], dict[str, str]]:
    kind = args.artifact_kind or ("target-files" if args.target_files else None)
    if kind not in ARTIFACT_KINDS:
        raise ValueError(f"unsupported artifact kind: {kind!r}")

    artifact_args = parse_assignments(args.artifact, "artifact")
    expected = parse_assignments(args.expected_sha256, "expected-sha256")
    metadata = parse_assignments(args.metadata, "metadata")

    if args.target_files:
        if kind != "target-files":
            raise ValueError("--target-files is only valid for artifact kind target-files")
        if "target_files" in artifact_args:
            raise ValueError("target_files supplied by both legacy and generic arguments")
        artifact_args["target_files"] = args.target_files
        if args.sha256:
            if "target_files" in expected:
                raise ValueError("target_files SHA supplied twice")
            expected["target_files"] = args.sha256
        if args.android_info:
            if "android_info" in artifact_args:
                raise ValueError("android_info supplied twice")
            artifact_args["android_info"] = args.android_info

    if kind == "target-files" and "target_files" not in artifact_args:
        raise ValueError("target-files registration requires target_files artifact")
    if kind == "target-files" and "android_info" not in artifact_args:
        raise ValueError("target-files registration requires android_info artifact")

    if not artifact_args:
        raise ValueError("at least one artifact is required")

    primary = args.primary_artifact or ("target_files" if kind == "target-files" else None)
    if not primary:
        raise ValueError("--primary-artifact is required for non-target-files registration")
    if primary not in artifact_args:
        raise ValueError(f"primary artifact is not registered: {primary}")

    paths = {name: pathlib.Path(value).resolve() for name, value in artifact_args.items()}
    for name, path in paths.items():
        if not path.is_file():
            raise FileNotFoundError(f"artifact {name} missing: {path}")

    unknown_expected = sorted(set(expected) - set(paths))
    if unknown_expected:
        raise ValueError(f"expected SHA names are not registered artifacts: {unknown_expected}")

    for name, digest in expected.items():
        if not SHA256_RE.fullmatch(digest):
            raise ValueError(f"invalid SHA-256 for {name}: {digest!r}")

    if primary not in expected:
        raise ValueError(f"expected SHA-256 required for primary artifact: {primary}")

    return kind, primary, paths, expected, metadata


def comparable_document(doc: dict) -> dict:
    keys = (
        "schema",
        "device",
        "release",
        "build_source",
        "tool_source",
        "artifact_kind",
        "primary_artifact",
        "artifacts",
        "metadata",
        "out_dir",
        "build_evidence_dir",
        "target_files",
        "target_files_sha256",
        "android_info",
        "android_info_sha256",
    )
    return {key: doc.get(key) for key in keys}


def register(args: argparse.Namespace) -> int:
    try:
        kind, primary, paths, expected, metadata = normalize_registration(args)
    except (ValueError, FileNotFoundError) as exc:
        print(f"SABLE_ARTIFACT_REGISTER=FAIL_INPUT detail={exc}", file=sys.stderr)
        return 2

    artifacts: dict[str, dict[str, object]] = {}
    for name in sorted(paths):
        path = paths[name]
        actual = sha256_file(path)
        artifacts[name] = {
            "path": str(path),
            "sha256": actual,
            "size": path.stat().st_size,
        }
        print(f"ARTIFACT_NAME={name}")
        print(f"ARTIFACT_PATH={path}")
        print(f"ARTIFACT_SHA256={actual}")
        if name in expected:
            print(f"EXPECTED_ARTIFACT_SHA256 name={name} value={expected[name]}")
            if actual != expected[name]:
                print(f"SABLE_ARTIFACT_REGISTER=FAIL_SHA256 name={name}")
                return 3

    root = pathlib.Path(args.registry_root).resolve()
    path = registry_path(root, args.device, args.release, args.build_source)
    path.parent.mkdir(parents=True, exist_ok=True)

    doc: dict[str, object] = {
        "schema": SCHEMA_VERSION,
        "device": args.device,
        "release": args.release,
        "build_source": args.build_source,
        "tool_source": args.tool_source,
        "artifact_kind": kind,
        "primary_artifact": primary,
        "artifacts": artifacts,
        "metadata": metadata,
        "out_dir": str(pathlib.Path(args.out_dir).resolve()) if args.out_dir else None,
        "build_evidence_dir": str(pathlib.Path(args.build_evidence_dir).resolve()) if args.build_evidence_dir else None,
        "registered_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

    # Panther/legacy compatibility aliases. These remain canonical aliases for
    # target-files records while new device classes use the generic artifact set.
    if kind == "target-files":
        tf = artifacts["target_files"]
        ai = artifacts["android_info"]
        doc.update(
            {
                "target_files": tf["path"],
                "target_files_sha256": tf["sha256"],
                "android_info": ai["path"],
                "android_info_sha256": ai["sha256"],
            }
        )

    if path.exists() and not args.replace:
        existing = json.loads(path.read_text(encoding="utf-8"))
        if existing.get("schema") == 1 and kind == "target-files":
            legacy_comparable = {
                "device": args.device,
                "release": args.release,
                "build_source": args.build_source,
                "target_files": doc["target_files"],
                "target_files_sha256": doc["target_files_sha256"],
                "android_info": doc["android_info"],
                "android_info_sha256": doc["android_info_sha256"],
                "out_dir": doc["out_dir"],
                "build_evidence_dir": doc["build_evidence_dir"],
            }
            if all(existing.get(k) == v for k, v in legacy_comparable.items()):
                print(f"ARTIFACT_MANIFEST={path}")
                print("SABLE_ARTIFACT_REGISTER=PASS_ALREADY_REGISTERED_SCHEMA1")
                return 0
        elif comparable_document(existing) == comparable_document(doc):
            print(f"ARTIFACT_MANIFEST={path}")
            print("SABLE_ARTIFACT_REGISTER=PASS_ALREADY_REGISTERED")
            return 0
        print(f"SABLE_ARTIFACT_REGISTER=FAIL_ALREADY_EXISTS_DIFFERENT path={path}")
        return 4

    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(doc, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(path)

    print(f"ARTIFACT_KIND={kind}")
    print(f"PRIMARY_ARTIFACT={primary}")
    print(f"ARTIFACT_MANIFEST={path}")
    print("SABLE_ARTIFACT_REGISTER=PASS")
    return 0


def load_manifest(args: argparse.Namespace) -> tuple[pathlib.Path, dict]:
    path = registry_path(
        pathlib.Path(args.registry_root).resolve(),
        args.device,
        args.release,
        args.build_source,
    )
    if not path.is_file():
        raise FileNotFoundError(path)
    return path, json.loads(path.read_text(encoding="utf-8"))


def show(args: argparse.Namespace) -> int:
    try:
        path, _doc = load_manifest(args)
    except FileNotFoundError as exc:
        print(f"SABLE_ARTIFACT_MANIFEST=NOT_FOUND path={exc}", file=sys.stderr)
        return 2
    print(path.read_text(encoding="utf-8"), end="")
    return 0


def resolve_field(doc: dict, field_name: str):
    if field_name in doc:
        return doc[field_name]
    if doc.get("schema") == 1:
        if field_name == "artifact_kind":
            return "target-files"
        if field_name == "primary_artifact":
            return "target_files"
        if field_name == "artifacts.target_files.path":
            return doc.get("target_files")
        if field_name == "artifacts.target_files.sha256":
            return doc.get("target_files_sha256")
        if field_name == "artifacts.android_info.path":
            return doc.get("android_info")
        if field_name == "artifacts.android_info.sha256":
            return doc.get("android_info_sha256")

    # Generic dotted artifact access, for example:
    # artifacts.system.path / artifacts.system.sha256 / artifacts.system.size
    parts = field_name.split(".")
    if len(parts) == 3 and parts[0] == "artifacts":
        return doc.get("artifacts", {}).get(parts[1], {}).get(parts[2])
    if len(parts) == 2 and parts[0] == "metadata":
        return doc.get("metadata", {}).get(parts[1])
    return None


def field(args: argparse.Namespace) -> int:
    try:
        _path, doc = load_manifest(args)
    except FileNotFoundError:
        return 2
    value = resolve_field(doc, args.field)
    if value is None:
        return 3
    if isinstance(value, (dict, list)):
        print(json.dumps(value, sort_keys=True))
    else:
        print(value)
    return 0


def verify(args: argparse.Namespace) -> int:
    try:
        path, doc = load_manifest(args)
    except FileNotFoundError as exc:
        print(f"SABLE_ARTIFACT_MANIFEST=NOT_FOUND path={exc}", file=sys.stderr)
        return 2

    schema = doc.get("schema")
    rows: list[tuple[str, pathlib.Path, str]] = []
    if schema == 1:
        rows = [
            ("target_files", pathlib.Path(doc["target_files"]), doc["target_files_sha256"]),
            ("android_info", pathlib.Path(doc["android_info"]), doc["android_info_sha256"]),
        ]
        kind = "target-files"
        primary = "target_files"
    elif schema == 2:
        kind = doc.get("artifact_kind")
        primary = doc.get("primary_artifact")
        artifacts = doc.get("artifacts")
        if kind not in ARTIFACT_KINDS or not isinstance(artifacts, dict) or primary not in artifacts:
            print("SABLE_ARTIFACT_MANIFEST_VERIFY=FAIL_SCHEMA2_STRUCTURE")
            return 5
        for name, row in sorted(artifacts.items()):
            if not isinstance(row, dict):
                print(f"SABLE_ARTIFACT_MANIFEST_VERIFY=FAIL_ARTIFACT_ROW name={name}")
                return 5
            rows.append((name, pathlib.Path(str(row.get("path", ""))), str(row.get("sha256", ""))))
    else:
        print(f"SABLE_ARTIFACT_MANIFEST_VERIFY=FAIL_SCHEMA value={schema!r}")
        return 5

    print(f"ARTIFACT_MANIFEST={path}")
    print(f"ARTIFACT_SCHEMA={schema}")
    print(f"ARTIFACT_KIND={kind}")
    print(f"PRIMARY_ARTIFACT={primary}")

    for name, artifact_path, expected in rows:
        if not artifact_path.is_file():
            print(f"SABLE_ARTIFACT_VERIFY=FAIL_MISSING name={name} path={artifact_path}")
            return 6
        if not SHA256_RE.fullmatch(expected):
            print(f"SABLE_ARTIFACT_VERIFY=FAIL_STORED_SHA name={name}")
            return 6
        actual = sha256_file(artifact_path)
        print(f"ARTIFACT_VERIFY name={name} expected={expected} actual={actual}")
        if actual != expected:
            print(f"SABLE_ARTIFACT_VERIFY=FAIL_SHA256 name={name}")
            return 7

    print("SABLE_ARTIFACT_MANIFEST_VERIFY=PASS")
    return 0


def make_namespace(**kwargs) -> argparse.Namespace:
    defaults = dict(
        registry_root="",
        device="",
        release="",
        build_source="",
        tool_source=None,
        artifact_kind=None,
        primary_artifact=None,
        artifact=[],
        expected_sha256=[],
        metadata=[],
        target_files=None,
        sha256=None,
        android_info=None,
        out_dir=None,
        build_evidence_dir=None,
        replace=False,
    )
    defaults.update(kwargs)
    return argparse.Namespace(**defaults)


def self_test() -> int:
    with tempfile.TemporaryDirectory() as td:
        root = pathlib.Path(td)
        registry = root / "registry"

        tf = root / "target_files.zip"
        ai = root / "android-info.txt"
        tf.write_bytes(b"target-files")
        ai.write_text("require board=panther\n", encoding="utf-8")
        digest = sha256_file(tf)

        legacy = make_namespace(
            registry_root=str(registry),
            device="panther",
            release="R9",
            build_source="0" * 40,
            tool_source="1" * 40,
            target_files=str(tf),
            sha256=digest,
            android_info=str(ai),
            out_dir=str(root / "out"),
            build_evidence_dir=str(root / "evidence"),
        )
        assert register(legacy) == 0
        assert register(legacy) == 0
        path = registry_path(registry, "panther", "R9", "0" * 40)
        doc = json.loads(path.read_text(encoding="utf-8"))
        assert doc["schema"] == 2
        assert doc["artifact_kind"] == "target-files"
        assert doc["primary_artifact"] == "target_files"
        assert doc["target_files_sha256"] == digest
        assert doc["artifacts"]["target_files"]["sha256"] == digest
        assert doc["artifacts"]["android_info"]["path"] == str(ai.resolve())
        verify_legacy = argparse.Namespace(
            registry_root=str(registry),
            device="panther",
            release="R9",
            build_source="0" * 40,
        )
        assert verify(verify_legacy) == 0

        gsi = root / "system.img"
        gsi.write_bytes(b"sable-gsi")
        gsi_digest = sha256_file(gsi)
        generic = make_namespace(
            registry_root=str(registry),
            device="titan2",
            release="R10",
            build_source="2" * 40,
            tool_source="3" * 40,
            artifact_kind="gsi-system-image",
            primary_artifact="system",
            artifact=[f"system={gsi}"],
            expected_sha256=[f"system={gsi_digest}"],
            metadata=["stock_basis=titan2-stock-a16-example"],
        )
        assert register(generic) == 0
        gpath = registry_path(registry, "titan2", "R10", "2" * 40)
        gdoc = json.loads(gpath.read_text(encoding="utf-8"))
        assert gdoc["schema"] == 2
        assert gdoc["artifact_kind"] == "gsi-system-image"
        assert gdoc["primary_artifact"] == "system"
        assert gdoc["artifacts"]["system"]["sha256"] == gsi_digest
        assert gdoc["metadata"]["stock_basis"] == "titan2-stock-a16-example"
        assert "target_files" not in gdoc
        verify_gsi = argparse.Namespace(
            registry_root=str(registry),
            device="titan2",
            release="R10",
            build_source="2" * 40,
        )
        assert verify(verify_gsi) == 0

        bad = make_namespace(
            registry_root=str(registry),
            device="titan2",
            release="R10",
            build_source="4" * 40,
            artifact_kind="gsi-system-image",
            primary_artifact="system",
            artifact=[f"system={gsi}"],
            expected_sha256=["system=" + "0" * 64],
        )
        assert register(bad) == 3

    print("SABLE_ARTIFACT_REGISTRY_SCHEMA=PASS_V2_BACKWARD_COMPATIBLE")
    print("SABLE_ARTIFACT_REGISTRY_GENERIC_GSI_SELF_TEST=PASS")
    print("SABLE_ARTIFACT_REGISTRY_SELF_TEST=PASS")
    return 0


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser()
    p.add_argument(
        "--registry-root",
        default="/srv/data/sable-build/release-registry",
    )
    sub = p.add_subparsers(dest="command", required=True)

    sub.add_parser("self-test")

    r = sub.add_parser("register")
    r.add_argument("--device", required=True)
    r.add_argument("--release", required=True)
    r.add_argument("--build-source", required=True)
    r.add_argument("--tool-source")
    r.add_argument("--artifact-kind", choices=ARTIFACT_KINDS)
    r.add_argument("--primary-artifact")
    r.add_argument("--artifact", action="append", default=[])
    r.add_argument("--expected-sha256", action="append", default=[])
    r.add_argument("--metadata", action="append", default=[])

    # Legacy target-files registration interface. Kept so validated Panther
    # release tooling and historical operator commands remain compatible.
    r.add_argument("--target-files")
    r.add_argument("--sha256")
    r.add_argument("--android-info")

    r.add_argument("--out-dir")
    r.add_argument("--build-evidence-dir")
    r.add_argument("--replace", action="store_true")

    v = sub.add_parser("verify")
    v.add_argument("--device", required=True)
    v.add_argument("--release", required=True)
    v.add_argument("--build-source", required=True)

    s = sub.add_parser("show")
    s.add_argument("--device", required=True)
    s.add_argument("--release", required=True)
    s.add_argument("--build-source", required=True)

    fld = sub.add_parser("field")
    fld.add_argument("--device", required=True)
    fld.add_argument("--release", required=True)
    fld.add_argument("--build-source", required=True)
    fld.add_argument("--field", required=True)
    return p


def main() -> int:
    args = parser().parse_args()
    if args.command == "self-test":
        return self_test()
    if args.command == "register":
        return register(args)
    if args.command == "verify":
        return verify(args)
    if args.command == "show":
        return show(args)
    if args.command == "field":
        return field(args)
    return 64


if __name__ == "__main__":
    raise SystemExit(main())
