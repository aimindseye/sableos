#!/usr/bin/env python3
"""Titan 2 N1I-D0 host-only boot-compatibility helpers.

Pure file analysis only. No device, network, build, source mutation or image
mutation. Missing inputs are surfaced explicitly; callers decide UNKNOWN vs
fatality using the R4 gate semantics.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import json
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

TOOL_VERSION = "1.0.0"
ANDROID_NS = "{http://schemas.android.com/apk/res/android}"
PRIVILEGED_FLAG = 0x10


class D0Error(Exception):
    pass


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_first(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace").splitlines()[0].strip()


def partition_path(root: Path, partition: str) -> Path:
    direct = root / partition
    if direct.is_dir():
        return direct
    if partition == "system" and (root / "build.prop").is_file():
        return root
    return direct


def policy_path(args: argparse.Namespace) -> int:
    roots = {
        "system": args.system_root,
        "system_ext": args.system_ext_root,
        "product": args.product_root,
        "vendor": args.vendor_root,
        "odm": args.odm_root,
    }
    for name, path in roots.items():
        if path is not None and not path.is_dir():
            raise D0Error(f"{name}_root_missing={path}")

    precompiled = None
    for name in ("odm", "vendor"):
        root = roots[name]
        if root is None:
            continue
        candidate = root / "etc/selinux/precompiled_sepolicy"
        if candidate.is_file():
            precompiled = candidate
            break

    rows: list[dict[str, str]] = []
    if precompiled is None:
        verdict = "SPLIT_COMPILE"
        reason = "precompiled_sepolicy_absent"
    else:
        specs = (
            ("system", "etc/selinux/plat_sepolicy_and_mapping.sha256",
             ".plat_sepolicy_and_mapping.sha256"),
            ("system_ext", "etc/selinux/system_ext_sepolicy_and_mapping.sha256",
             ".system_ext_sepolicy_and_mapping.sha256"),
            ("product", "etc/selinux/product_sepolicy_and_mapping.sha256",
             ".product_sepolicy_and_mapping.sha256"),
        )
        verdict = "PRECOMPILED_USED"
        reason = "all_present_hash_pairs_match"
        for part, rel, suffix in specs:
            root = roots[part]
            actual = (root / rel) if root is not None else None
            expected = Path(str(precompiled) + suffix)
            actual_exists = bool(actual and actual.is_file())
            expected_exists = expected.is_file()
            actual_id = read_first(actual) if actual_exists and actual else "-"
            expected_id = read_first(expected) if expected_exists else "-"
            if not actual_exists and not expected_exists:
                status = "BOTH_ABSENT_INIT_CONTINUES"
            elif actual_exists and expected_exists and actual_id and actual_id == expected_id:
                status = "MATCH"
            else:
                status = "MISMATCH_OR_ONE_SIDED"
                verdict = "SPLIT_COMPILE"
                reason = f"{part}_policy_identity_not_precompiled_match"
            rows.append({
                "partition": part,
                "actual_path": str(actual or "-"),
                "precompiled_path": str(expected),
                "actual_id": actual_id,
                "precompiled_id": expected_id,
                "status": status,
            })

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8", newline="") as fp:
        w = csv.DictWriter(fp, fieldnames=[
            "partition", "actual_path", "precompiled_path",
            "actual_id", "precompiled_id", "status",
        ], delimiter="\t")
        w.writeheader()
        w.writerows(rows)

    print(f"N1I_D0_A0_POLICY_PATH={verdict}")
    print(f"N1I_D0_A0_REASON={reason}")
    print(f"N1I_D0_A0_PRECOMPILED={precompiled or '-'}")
    return 0


@dataclass(frozen=True)
class ContextRow:
    partition: str
    file: str
    key: str
    context: str
    match: str
    line: int


def strip_comment(raw: str) -> str:
    return raw.split("#", 1)[0].strip()


def parse_context_file(path: Path, partition: str, kind: str) -> list[ContextRow]:
    out: list[ContextRow] = []
    for lineno, raw in enumerate(path.read_text(
        encoding="utf-8", errors="replace"
    ).splitlines(), 1):
        line = strip_comment(raw)
        if not line:
            continue
        cols = line.split()
        if len(cols) < 2:
            continue
        key, context = cols[0], cols[1]
        match = cols[2] if kind == "property" and len(cols) >= 3 else "exact"
        out.append(ContextRow(
            partition=partition,
            file=str(path),
            key=key,
            context=context,
            match=match,
            line=lineno,
        ))
    return out


def discover_contexts(spec: str, kind: str) -> list[ContextRow]:
    try:
        partition, raw = spec.split("=", 1)
    except ValueError as exc:
        raise D0Error(f"invalid_root_spec={spec}") from exc
    root = Path(raw)
    if not root.is_dir():
        raise D0Error(f"context_root_missing={spec}")
    selinux = root / "etc/selinux"
    if not selinux.is_dir():
        return []
    patterns = (
        "*property_contexts" if kind == "property" else "*service_contexts"
    )
    rows: list[ContextRow] = []
    for path in sorted(selinux.glob(patterns)):
        if path.is_file():
            rows.extend(parse_context_file(path, partition, kind))
    return rows


def contexts(args: argparse.Namespace) -> int:
    rows: list[ContextRow] = []
    for spec in args.root:
        rows.extend(discover_contexts(spec, args.kind))

    grouped: dict[str, list[ContextRow]] = {}
    for row in rows:
        grouped.setdefault(row.key, []).append(row)

    conflicts: list[dict[str, str]] = []
    for key, group in sorted(grouped.items()):
        signatures = {(x.context, x.match) for x in group}
        if len(signatures) <= 1:
            continue
        conflicts.append({
            "kind": args.kind,
            "key": key,
            "status": "EXACT_KEY_CONFLICT",
            "definitions": " | ".join(
                f"{x.partition}:{x.context}:{x.match}:{x.file}:{x.line}"
                for x in group
            ),
        })

    if args.kind == "property":
        prefix_rows = [x for x in rows if x.match.lower() == "prefix"]
        exact_rows = [x for x in rows if x.match.lower() != "prefix"]
        for p in prefix_rows:
            for e in exact_rows:
                if e.key.startswith(p.key) and e.context != p.context:
                    conflicts.append({
                        "kind": args.kind,
                        "key": f"{p.key} -> {e.key}",
                        "status": "PREFIX_OVERLAP_DIFFERENT_TYPE",
                        "definitions": (
                            f"{p.partition}:{p.context}:prefix:{p.file}:{p.line}"
                            " | "
                            f"{e.partition}:{e.context}:{e.match}:{e.file}:{e.line}"
                        ),
                    })

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8", newline="") as fp:
        w = csv.DictWriter(fp, fieldnames=[
            "kind", "key", "status", "definitions",
        ], delimiter="\t")
        w.writeheader()
        w.writerows(conflicts)

    print(f"N1I_D0_CONTEXT_KIND={args.kind.upper()}")
    print(f"N1I_D0_CONTEXT_ROW_COUNT={len(rows)}")
    print(f"N1I_D0_CONTEXT_CONFLICT_COUNT={len(conflicts)}")
    print(
        "N1I_D0_CONTEXT_RESULT="
        + ("PASS_NO_STATIC_CONFLICT" if not conflicts else "FINDINGS")
    )
    return 0


def iter_xml(root: Path) -> Iterable[Path]:
    if not root.is_dir():
        return []
    perms = root / "etc/permissions"
    if not perms.is_dir():
        return []
    return sorted(perms.glob("*.xml"))


def privapp_blocks(root_spec: str, package: str) -> list[dict[str, object]]:
    partition, raw = root_spec.split("=", 1)
    root = Path(raw)
    out: list[dict[str, object]] = []
    for path in iter_xml(root):
        try:
            tree = ET.parse(path)
        except ET.ParseError:
            continue
        for el in tree.getroot().iter("privapp-permissions"):
            if el.attrib.get("package") != package:
                continue
            allow = sorted({
                child.attrib.get("name", "")
                for child in el.findall("permission")
                if child.attrib.get("name")
            })
            deny = sorted({
                child.attrib.get("name", "")
                for child in el.findall("deny-permission")
                if child.attrib.get("name")
            })
            out.append({
                "partition": partition,
                "path": str(path),
                "allow": allow,
                "deny": deny,
            })
    return out


USES_RE = re.compile(
    r"uses-permission(?:-sdk-[0-9]+)?:\s+name='([^']+)'"
)


def parse_requested_permissions(path: Path) -> set[str]:
    text = path.read_text(encoding="utf-8", errors="replace")
    return set(USES_RE.findall(text))


def parse_framework_privileged(path: Path) -> dict[str, int]:
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    result: dict[str, int] = {}
    in_permission = False
    name: str | None = None
    level: int | None = None

    def flush() -> None:
        nonlocal name, level
        if name is not None and level is not None and level & PRIVILEGED_FLAG:
            result[name] = level
        name = None
        level = None

    for raw in lines:
        line = raw.strip()
        if line.startswith("E: permission "):
            flush()
            in_permission = True
            continue
        if line.startswith("E: ") and not line.startswith("E: permission "):
            if in_permission:
                flush()
            in_permission = False
            continue
        if not in_permission:
            continue
        if "android:name" in line:
            m = re.search(r'="([^"]+)"', line)
            if m:
                name = m.group(1)
        elif "android:protectionLevel" in line:
            vals = re.findall(r"0x[0-9a-fA-F]+", line)
            if vals:
                level = int(vals[-1], 16)
    if in_permission:
        flush()
    return result


def privapp(args: argparse.Namespace) -> int:
    requested = parse_requested_permissions(args.apk_permissions)
    framework = parse_framework_privileged(args.framework_manifest)
    if not framework:
        raise D0Error("framework_privileged_permission_parse_empty")

    stock_blocks: list[dict[str, object]] = []
    for spec in args.stock_root:
        stock_blocks.extend(privapp_blocks(spec, args.package))

    candidate_blocks: list[dict[str, object]] = []
    for spec in args.candidate_root:
        candidate_blocks.extend(privapp_blocks(spec, args.package))

    candidate_partition_blocks = [
        x for x in candidate_blocks
        if x["partition"] == args.candidate_partition
    ]
    allow = set()
    deny = set()
    for block in candidate_partition_blocks:
        allow.update(block["allow"])
        deny.update(block["deny"])

    required = sorted(requested & set(framework))
    missing = sorted(set(required) - allow - deny)

    result = {
        "package": args.package,
        "candidate_partition": args.candidate_partition,
        "requested_permissions": sorted(requested),
        "framework_privileged_permissions": framework,
        "required_allowlist": required,
        "candidate_allowed": sorted(allow),
        "candidate_denied": sorted(deny),
        "missing_required": missing,
        "stock_blocks": stock_blocks,
        "candidate_blocks": candidate_blocks,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")

    print(f"N1I_D0_PRIVAPP_REQUESTED_COUNT={len(requested)}")
    print(f"N1I_D0_PRIVAPP_REQUIRED_ALLOWLIST_COUNT={len(required)}")
    print(f"N1I_D0_PRIVAPP_SYSTEM_EXT_BLOCK_COUNT={len(candidate_partition_blocks)}")
    print(f"N1I_D0_PRIVAPP_MISSING_REQUIRED_COUNT={len(missing)}")
    print(
        "N1I_D0_PRIVAPP_COVERAGE="
        + ("PASS" if not missing and candidate_partition_blocks else "FAIL")
    )
    return 0



def parse_badging_package(text: str) -> str:
    m = re.search(r"^package:\s+name='([^']+)'", text, re.MULTILINE)
    return m.group(1) if m else ""


def all_allowlists(specs: list[str]) -> dict[tuple[str, str], tuple[set[str], set[str], list[str]]]:
    index: dict[tuple[str, str], tuple[set[str], set[str], list[str]]] = {}
    for spec in specs:
        partition, raw = spec.split("=", 1)
        root = Path(raw)
        for path in iter_xml(root):
            try:
                tree = ET.parse(path)
            except ET.ParseError:
                continue
            for el in tree.getroot().iter("privapp-permissions"):
                package = el.attrib.get("package", "")
                if not package:
                    continue
                key = (partition, package)
                allow, deny, files = index.setdefault(key, (set(), set(), []))
                allow.update(
                    child.attrib.get("name", "")
                    for child in el.findall("permission")
                    if child.attrib.get("name")
                )
                deny.update(
                    child.attrib.get("name", "")
                    for child in el.findall("deny-permission")
                    if child.attrib.get("name")
                )
                files.append(str(path))
    return index


def privapp_tree(args: argparse.Namespace) -> int:
    framework = parse_framework_privileged(args.framework_manifest)
    if not framework:
        raise D0Error("framework_privileged_permission_parse_empty")

    roots: list[tuple[str, Path]] = []
    specs = args.root
    for spec in specs:
        partition, raw = spec.split("=", 1)
        root = Path(raw)
        if not root.is_dir():
            raise D0Error(f"privapp_root_missing={spec}")
        roots.append((partition, root))

    allowlists = all_allowlists(specs)
    rows: list[dict[str, str]] = []
    failures = 0
    for partition, root in roots:
        priv = root / "priv-app"
        if not priv.is_dir():
            continue
        for apk in sorted(priv.rglob("*.apk")):
            badging = subprocess.run(
                [str(args.aapt2), "dump", "badging", str(apk)],
                capture_output=True,
                text=True,
                check=False,
            )
            perms = subprocess.run(
                [str(args.aapt2), "dump", "permissions", str(apk)],
                capture_output=True,
                text=True,
                check=False,
            )
            if badging.returncode or perms.returncode:
                rows.append({
                    "partition": partition,
                    "package": "-",
                    "apk": str(apk),
                    "required_count": "-",
                    "missing_count": "-",
                    "missing": "AAPT2_PARSE_FAILED",
                    "allowlist_files": "-",
                    "status": "UNKNOWN",
                })
                failures += 1
                continue
            package = parse_badging_package(badging.stdout)
            if not package:
                rows.append({
                    "partition": partition,
                    "package": "-",
                    "apk": str(apk),
                    "required_count": "-",
                    "missing_count": "-",
                    "missing": "PACKAGE_PARSE_FAILED",
                    "allowlist_files": "-",
                    "status": "UNKNOWN",
                })
                failures += 1
                continue
            requested = set(USES_RE.findall(perms.stdout))
            required = requested & set(framework)
            allow, deny, files = allowlists.get(
                (partition, package), (set(), set(), [])
            )
            missing = sorted(required - allow - deny)
            status = "PASS" if not missing else "FAIL"
            failures += int(status != "PASS")
            rows.append({
                "partition": partition,
                "package": package,
                "apk": str(apk),
                "required_count": str(len(required)),
                "missing_count": str(len(missing)),
                "missing": ",".join(missing) or "NONE",
                "allowlist_files": ",".join(files) or "NONE",
                "status": status,
            })

    args.out.parent.mkdir(parents=True, exist_ok=True)
    fields = (
        "partition", "package", "apk", "required_count", "missing_count",
        "missing", "allowlist_files", "status",
    )
    with args.out.open("w", encoding="utf-8", newline="") as fp:
        w = csv.DictWriter(fp, fieldnames=fields, delimiter="\t")
        w.writeheader()
        w.writerows(rows)

    print(f"N1I_D0_PRIVAPP_TREE_APP_COUNT={len(rows)}")
    print(f"N1I_D0_PRIVAPP_TREE_NONPASS_COUNT={failures}")
    print(
        "N1I_D0_PRIVAPP_TREE="
        + ("PASS" if rows and failures == 0 else "FAIL_OR_UNKNOWN")
    )
    return 0


def parse_seapp_file(path: Path, partition: str) -> list[dict[str, str]]:
    rows = []
    for lineno, raw in enumerate(
        path.read_text(encoding="utf-8", errors="replace").splitlines(), 1
    ):
        line = strip_comment(raw)
        if not line:
            continue
        fields: dict[str, str] = {}
        for token in line.split():
            if "=" not in token:
                continue
            key, value = token.split("=", 1)
            fields[key] = value
        if not fields:
            continue
        fields["partition"] = partition
        fields["file"] = str(path)
        fields["line"] = str(lineno)
        rows.append(fields)
    return rows


def seapp(args: argparse.Namespace) -> int:
    rows = []
    for spec in args.root:
        partition, raw = spec.split("=", 1)
        root = Path(raw)
        if not root.is_dir():
            raise D0Error(f"seapp_root_missing={spec}")
        selinux = root / "etc/selinux"
        if not selinux.is_dir():
            continue
        for path in sorted(selinux.glob("*seapp_contexts")):
            rows.extend(parse_seapp_file(path, partition))

    selected = []
    for row in rows:
        if args.user and row.get("user") == args.user:
            selected.append(row)
            continue
        if args.name and row.get("name") == args.name:
            selected.append(row)
            continue
        if args.seinfo and row.get("seinfo") == args.seinfo:
            selected.append(row)

    fields = [
        "partition", "file", "line", "user", "seinfo", "name", "domain",
        "type", "levelFrom", "isPrivApp", "minTargetSdkVersion",
    ]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8", newline="") as fp:
        w = csv.DictWriter(fp, fieldnames=fields, delimiter="\t",
                           extrasaction="ignore")
        w.writeheader()
        for row in selected:
            w.writerow({key: row.get(key, "-") for key in fields})
    print(f"N1I_D0_SEAPP_MATCH_COUNT={len(selected)}")
    print("N1I_D0_SEAPP_RESULT=" + ("FOUND" if selected else "NOT_FOUND"))
    return 0



def load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise D0Error(f"cannot_load_python_module={path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def detect_payload_fs(path: Path) -> str:
    with path.open("rb") as fp:
        header = fp.read(1084)
    if len(header) >= 1082 and header[1080:1082] == b"\x53\xef":
        return "ext4"
    if len(header) >= 1028 and header[1024:1028] == b"\xe2\xe1\xf5\xe0":
        return "erofs"
    raise D0Error(f"unsupported_apex_payload_fs={path}")


def extract_zip_member(zf: zipfile.ZipFile, member: str, dest: Path) -> None:
    with zf.open(member) as src, dest.open("wb") as dst:
        shutil.copyfileobj(src, dst, 1024 * 1024)


def apex_extract(args: argparse.Namespace) -> int:
    archive_root = args.system_root / "apex"
    if not archive_root.is_dir():
        raise D0Error(f"apex_archive_root_missing={archive_root}")
    if args.out.exists() and any(args.out.iterdir()):
        raise D0Error(f"apex_output_not_empty={args.out}")
    args.out.mkdir(parents=True, exist_ok=True)

    archives = sorted(
        p for p in archive_root.iterdir()
        if p.is_file() and p.suffix in (".apex", ".capex")
    )
    if not archives:
        raise D0Error(f"apex_archives_absent={archive_root}")

    rows = []
    seen_modules: set[str] = set()
    work = args.out.parent / (args.out.name + ".work")
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    try:
        for archive in archives:
            module_name = re.sub(r"\.(?:c?apex)$", "", archive.name)
            if module_name in seen_modules:
                raise D0Error(f"duplicate_apex_module_archive={module_name}")
            seen_modules.add(module_name)

            safe = re.sub(r"[^A-Za-z0-9_.-]", "_", module_name)
            inner = work / f"{safe}.inner.apex"
            payload = work / f"{safe}.payload.img"
            outer_sha = sha256(archive)
            inner_path = archive

            with zipfile.ZipFile(archive) as outer:
                if "original_apex" in outer.namelist():
                    extract_zip_member(outer, "original_apex", inner)
                    inner_path = inner

            inner_sha = sha256(inner_path)
            with zipfile.ZipFile(inner_path) as zf:
                if "apex_payload.img" not in zf.namelist():
                    raise D0Error(f"apex_payload_missing={archive}")
                extract_zip_member(zf, "apex_payload.img", payload)

            payload_sha = sha256(payload)
            fs_type = detect_payload_fs(payload)
            dest = args.out / f"{module_name}.apex"
            dest.mkdir()

            if fs_type == "ext4":
                cmd = [
                    str(args.debugfs),
                    "-R",
                    f"rdump / {dest}",
                    str(payload),
                ]
            else:
                cmd = [
                    str(args.fsck_erofs),
                    f"--extract={dest}",
                    str(payload),
                ]
            cp = subprocess.run(
                cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, check=False,
            )
            (work / f"{safe}.extract.log").write_text(
                cp.stdout, encoding="utf-8", errors="replace"
            )
            if cp.returncode != 0 or not any(dest.iterdir()):
                raise D0Error(
                    f"apex_extract_failed={module_name}:rc={cp.returncode}"
                )

            rows.append({
                "module": module_name,
                "archive": str(archive),
                "outer_sha256": outer_sha,
                "inner_sha256": inner_sha,
                "payload_sha256": payload_sha,
                "payload_fs": fs_type,
                "extracted_root": str(dest),
            })
            inner.unlink(missing_ok=True)
            payload.unlink(missing_ok=True)
    finally:
        shutil.rmtree(work, ignore_errors=True)

    manifest = args.out / "N1I_D0_APEX_MANIFEST.tsv"
    with manifest.open("w", encoding="utf-8", newline="") as fp:
        fields = (
            "module", "archive", "outer_sha256", "inner_sha256",
            "payload_sha256", "payload_fs", "extracted_root",
        )
        w = csv.DictWriter(fp, fieldnames=fields, delimiter="\t")
        w.writeheader()
        w.writerows(rows)
    print(f"N1I_D0_APEX_MODULE_COUNT={len(rows)}")
    print("N1I_D0_APEX_EXTRACTION=PASS")
    return 0


def map_runtime_path(
    system_root: Path,
    system_ext_root: Path,
    product_root: Path,
    apex_root: Path,
    device: str,
) -> Path:
    if device.startswith("/system_ext/"):
        return system_ext_root / device.removeprefix("/system_ext/")
    if device.startswith("/product/"):
        return product_root / device.removeprefix("/product/")
    if device.startswith("/system/"):
        return system_root / device.removeprefix("/system/")
    if device.startswith("/apex/"):
        parts = device.split("/", 3)
        if len(parts) != 4:
            raise D0Error(f"invalid_apex_runtime_path={device}")
        module = parts[2]
        exact = apex_root / f"{module}.apex"
        if not exact.is_dir():
            hits = sorted(
                p for p in apex_root.glob(f"{module}*")
                if p.is_dir() and
                re.sub(r"\.(?:c?apex)$", "", p.name) == module
            )
            if len(hits) != 1:
                raise D0Error(
                    f"apex_runtime_module_count={module}:{len(hits)}"
                )
            exact = hits[0]
        return exact / parts[3]
    raise D0Error(f"unsupported_runtime_path={device}")


def classpath(args: argparse.Namespace) -> int:
    deriver = load_module(
        args.repo / "build/titan2/derive-n1i-c1-runtime-classpath.py",
        "n1i_d0_deriver",
    )
    static = load_module(args.static_tool, "n1i_d0_static")
    system_fragment = args.system_root / "etc/classpaths/bootclasspath.pb"
    if not system_fragment.is_file():
        raise D0Error(f"system_bootclasspath_missing={system_fragment}")
    if not args.apex_root.is_dir():
        raise D0Error(f"apex_root_missing={args.apex_root}")

    system_jars = list(deriver.boot_jars(system_fragment, args.api_level))
    fragments = list(deriver.apex_fragments(args.apex_root, args.api_level))
    by_module = {x.module: x for x in fragments}

    ordered: list[tuple[str, str]] = []
    art = by_module.get("com.android.art")
    if art:
        ordered.extend((j.path, "APEX:com.android.art") for j in art.jars)
    ordered.extend((j.path, "SYSTEM_FRAGMENT") for j in system_jars)
    for module in sorted(by_module):
        if module == "com.android.art":
            continue
        ordered.extend(
            (j.path, f"APEX:{module}") for j in by_module[module].jars
        )

    seen_paths: set[str] = set()
    bcp: list[tuple[str, str, Path]] = []
    duplicate_device_paths = []
    for device, source in ordered:
        if device in seen_paths:
            duplicate_device_paths.append((device, source))
            continue
        seen_paths.add(device)
        host = map_runtime_path(
            args.system_root,
            args.system_ext_root,
            args.product_root,
            args.apex_root,
            device,
        )
        bcp.append((device, source, host))

    systemserver: list[tuple[str, str, Path]] = []
    ss_fragments = []
    candidates = [
        args.system_root / "etc/classpaths/systemserverclasspath.pb",
        *sorted(args.apex_root.glob(
            "*/etc/classpaths/systemserverclasspath.pb"
        )),
    ]
    for fragment in candidates:
        if not fragment.is_file():
            continue
        for jar in deriver.parse_fragment(fragment):
            if not deriver.enabled(jar, args.api_level):
                continue
            source = "SYSTEMSERVER:" + str(fragment)
            host = map_runtime_path(
                args.system_root,
                args.system_ext_root,
                args.product_root,
                args.apex_root,
                jar.path,
            )
            systemserver.append((jar.path, source, host))
            ss_fragments.append(str(fragment))

    all_rows = []
    missing = 0
    for order, (device, source, host) in enumerate(bcp):
        exists = host.is_file()
        missing += int(not exists)
        all_rows.append({
            "classpath": "BOOT",
            "order": str(order),
            "device": device,
            "source": source,
            "host": str(host),
            "exists": "YES" if exists else "NO",
            "sha256": sha256(host) if exists else "-",
        })
    for order, (device, source, host) in enumerate(systemserver):
        exists = host.is_file()
        missing += int(not exists)
        all_rows.append({
            "classpath": "SYSTEMSERVER",
            "order": str(order),
            "device": device,
            "source": source,
            "host": str(host),
            "exists": "YES" if exists else "NO",
            "sha256": sha256(host) if exists else "-",
        })

    args.out.mkdir(parents=True, exist_ok=True)
    with (args.out / "CLASSPATH.tsv").open(
        "w", encoding="utf-8", newline=""
    ) as fp:
        fields = (
            "classpath", "order", "device", "source", "host", "exists",
            "sha256",
        )
        w = csv.DictWriter(fp, fieldnames=fields, delimiter="\t")
        w.writeheader()
        w.writerows(all_rows)

    owners: dict[str, tuple[str, str]] = {}
    duplicate_classes = []
    shadow_count = 0
    for row in all_rows:
        host = Path(row["host"])
        if not host.is_file():
            continue
        try:
            container = static.load_container(host)
        except Exception as exc:
            raise D0Error(
                f"classpath_dex_parse_failed={host}:{type(exc).__name__}:{exc}"
            ) from exc
        for entry, dex in container.dexes:
            for cd in dex.classes:
                owner = (row["classpath"], row["device"])
                first = owners.get(cd.descriptor)
                if first is None:
                    owners[cd.descriptor] = owner
                    continue
                duplicate_classes.append((
                    cd.descriptor,
                    first[0],
                    first[1],
                    owner[0],
                    owner[1],
                ))
                if first != owner:
                    shadow_count += 1

    with (args.out / "DUPLICATE_CLASSES.tsv").open(
        "w", encoding="utf-8", newline=""
    ) as fp:
        w = csv.writer(fp, delimiter="\t")
        w.writerow((
            "class", "winner_classpath", "winner_device",
            "shadow_classpath", "shadow_device",
        ))
        w.writerows(duplicate_classes)

    updatable_files = sorted(
        args.system_root.rglob("updatable-bcp-packages.txt")
    )
    updatable_rows = []
    for path in updatable_files:
        for raw in path.read_text(
            encoding="utf-8", errors="replace"
        ).splitlines():
            line = strip_comment(raw)
            if line:
                updatable_rows.append((str(path), line))
    with (args.out / "UPDATABLE_BCP_PACKAGES.tsv").open(
        "w", encoding="utf-8", newline=""
    ) as fp:
        w = csv.writer(fp, delimiter="\t")
        w.writerow(("source", "package"))
        w.writerows(updatable_rows)

    with (args.out / "SUMMARY.env").open("w", encoding="utf-8") as fp:
        fp.write(f"N1I_D0_BCP_ENTRY_COUNT={len(bcp)}\n")
        fp.write(
            f"N1I_D0_SYSTEMSERVER_ENTRY_COUNT={len(systemserver)}\n"
        )
        fp.write(f"N1I_D0_CLASSPATH_MISSING_COUNT={missing}\n")
        fp.write(
            f"N1I_D0_DUPLICATE_DEVICE_PATH_COUNT="
            f"{len(duplicate_device_paths)}\n"
        )
        fp.write(
            f"N1I_D0_DUPLICATE_CLASS_COUNT={len(duplicate_classes)}\n"
        )
        fp.write(f"N1I_D0_DUPLICATE_SHADOW_COUNT={shadow_count}\n")
        fp.write(
            f"N1I_D0_UPDATABLE_BCP_PACKAGE_COUNT="
            f"{len(updatable_rows)}\n"
        )
        fp.write(
            "N1I_D0_CLASSPATH_PATH_RESOLUTION="
            + ("PASS" if missing == 0 else "FAIL")
            + "\n"
        )

    print(f"N1I_D0_BCP_ENTRY_COUNT={len(bcp)}")
    print(f"N1I_D0_SYSTEMSERVER_ENTRY_COUNT={len(systemserver)}")
    print(f"N1I_D0_CLASSPATH_MISSING_COUNT={missing}")
    print(f"N1I_D0_DUPLICATE_CLASS_COUNT={len(duplicate_classes)}")
    print(
        "N1I_D0_CLASSPATH_PATH_RESOLUTION="
        + ("PASS" if missing == 0 else "FAIL")
    )
    return 0


def inventory(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    if not root.is_dir():
        raise D0Error(f"inventory_root_missing={root}")
    categories = (
        "/etc/selinux/",
        "/etc/permissions/",
        "/etc/sysconfig/",
        "/etc/classpaths/",
        "/etc/init/",
        "/framework/",
        "/priv-app/",
        "/apex/",
        "/lib64/",
    )
    rows: list[tuple[str, int, str]] = []
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        rel = "/" + str(path.relative_to(root))
        if not any(token in rel for token in categories):
            continue
        rows.append((rel, path.stat().st_size, sha256(path)))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8", newline="") as fp:
        w = csv.writer(fp, delimiter="\t")
        w.writerow(("path", "bytes", "sha256"))
        w.writerows(rows)
    print(f"N1I_D0_INVENTORY_COUNT={len(rows)}")
    return 0


def compare_inventory(args: argparse.Namespace) -> int:
    def load(path: Path) -> dict[str, tuple[str, str]]:
        rows = {}
        with path.open(encoding="utf-8") as fp:
            for row in csv.DictReader(fp, delimiter="\t"):
                rows[row["path"]] = (row["bytes"], row["sha256"])
        return rows

    left = load(args.left)
    right = load(args.right)
    names = sorted(set(left) | set(right))
    out = []
    for name in names:
        l = left.get(name)
        r = right.get(name)
        if l == r:
            continue
        if l is None:
            status = "ADDED"
        elif r is None:
            status = "REMOVED"
        else:
            status = "CHANGED"
        out.append((name, status, *(l or ("-", "-")), *(r or ("-", "-"))))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8", newline="") as fp:
        w = csv.writer(fp, delimiter="\t")
        w.writerow((
            "path", "status", "left_bytes", "left_sha256",
            "right_bytes", "right_sha256",
        ))
        w.writerows(out)
    print(f"N1I_D0_DELTA_COUNT={len(out)}")
    return 0


def selftest() -> int:
    import tempfile

    with tempfile.TemporaryDirectory() as raw:
        root = Path(raw)
        sysroot = root / "system"
        ext = root / "system_ext"
        product = root / "product"
        vendor = root / "vendor"
        for p in (sysroot, ext, product, vendor):
            (p / "etc/selinux").mkdir(parents=True)

        (vendor / "etc/selinux/precompiled_sepolicy").write_text("x")
        (sysroot / "etc/selinux/plat_sepolicy_and_mapping.sha256").write_text("A\n")
        (Path(str(vendor / "etc/selinux/precompiled_sepolicy") +
              ".plat_sepolicy_and_mapping.sha256")).write_text("B\n")
        for part, base in (
            (ext, "system_ext_sepolicy_and_mapping"),
            (product, "product_sepolicy_and_mapping"),
        ):
            (part / f"etc/selinux/{base}.sha256").write_text("C\n")
            (Path(str(vendor / "etc/selinux/precompiled_sepolicy") +
                  f".{base}.sha256")).write_text("C\n")

        ns = argparse.Namespace(
            system_root=sysroot,
            system_ext_root=ext,
            product_root=product,
            vendor_root=vendor,
            odm_root=None,
            out=root / "a0.tsv",
        )
        assert policy_path(ns) == 0
        assert (root / "a0.tsv").is_file()

        (sysroot / "etc/selinux/plat_property_contexts").write_text(
            "persist.demo u:object_r:type_a:s0 exact\n"
        )
        (vendor / "etc/selinux/vendor_property_contexts").write_text(
            "persist.demo u:object_r:type_b:s0 exact\n"
        )
        ns = argparse.Namespace(
            root=[f"system={sysroot}", f"vendor={vendor}"],
            kind="property",
            out=root / "contexts.tsv",
        )
        assert contexts(ns) == 0
        assert "EXACT_KEY_CONFLICT" in (root / "contexts.tsv").read_text()

        # Gate-D partition-scoped allowlist fixture. The package requests two
        # privileged permissions but the system_ext allowlist covers only one.
        sysperm = sysroot / "etc/permissions"
        extperm = ext / "etc/permissions"
        sysperm.mkdir(parents=True, exist_ok=True)
        extperm.mkdir(parents=True, exist_ok=True)
        (sysperm / "wrong.xml").write_text(
            "<permissions><privapp-permissions package=\"com.mediatek.ims\">"
            "<permission name=\"android.permission.P1\"/>"
            "<permission name=\"android.permission.P2\"/>"
            "</privapp-permissions></permissions>"
        )
        (extperm / "right.xml").write_text(
            "<permissions><privapp-permissions package=\"com.mediatek.ims\">"
            "<permission name=\"android.permission.P1\"/>"
            "</privapp-permissions></permissions>"
        )
        apk_perms = root / "apk-permissions.txt"
        apk_perms.write_text(
            "uses-permission: name='android.permission.P1'\n"
            "uses-permission: name='android.permission.P2'\n"
        )
        framework = root / "framework-manifest.txt"
        framework.write_text(
            "E: manifest\n"
            "  E: permission\n"
            "    A: android:name(0x01010003)=\"android.permission.P1\"\n"
            "    A: android:protectionLevel(0x01010009)=0x10\n"
            "  E: permission\n"
            "    A: android:name(0x01010003)=\"android.permission.P2\"\n"
            "    A: android:protectionLevel(0x01010009)=0x10\n"
        )
        ns = argparse.Namespace(
            package="com.mediatek.ims",
            candidate_partition="system_ext",
            apk_permissions=apk_perms,
            framework_manifest=framework,
            stock_root=[f"system={sysroot}"],
            candidate_root=[
                f"system={sysroot}",
                f"system_ext={ext}",
                f"product={product}",
            ],
            out=root / "privapp.json",
        )
        assert privapp(ns) == 0
        priv = json.loads((root / "privapp.json").read_text())
        assert priv["missing_required"] == ["android.permission.P2"]

    print("N1I_D0_HOST_HELPER_SELFTEST=PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser()
    sp = p.add_subparsers(dest="cmd", required=False)

    a = sp.add_parser("policy-path")
    a.add_argument("--system-root", type=Path, required=True)
    a.add_argument("--system-ext-root", type=Path, required=True)
    a.add_argument("--product-root", type=Path, required=True)
    a.add_argument("--vendor-root", type=Path, required=True)
    a.add_argument("--odm-root", type=Path)
    a.add_argument("--out", type=Path, required=True)

    c = sp.add_parser("contexts")
    c.add_argument("--kind", choices=("property", "service"), required=True)
    c.add_argument("--root", action="append", required=True)
    c.add_argument("--out", type=Path, required=True)

    pr = sp.add_parser("privapp")
    pr.add_argument("--package", required=True)
    pr.add_argument("--candidate-partition", required=True)
    pr.add_argument("--apk-permissions", type=Path, required=True)
    pr.add_argument("--framework-manifest", type=Path, required=True)
    pr.add_argument("--stock-root", action="append", required=True)
    pr.add_argument("--candidate-root", action="append", required=True)
    pr.add_argument("--out", type=Path, required=True)

    ax = sp.add_parser("apex-extract")
    ax.add_argument("--system-root", type=Path, required=True)
    ax.add_argument("--debugfs", type=Path, required=True)
    ax.add_argument("--fsck-erofs", type=Path, required=True)
    ax.add_argument("--out", type=Path, required=True)

    cp = sp.add_parser("classpath")
    cp.add_argument("--repo", type=Path, required=True)
    cp.add_argument("--system-root", type=Path, required=True)
    cp.add_argument("--system-ext-root", type=Path, required=True)
    cp.add_argument("--product-root", type=Path, required=True)
    cp.add_argument("--apex-root", type=Path, required=True)
    cp.add_argument("--static-tool", type=Path, required=True)
    cp.add_argument("--api-level", type=int, default=36)
    cp.add_argument("--out", type=Path, required=True)

    pt = sp.add_parser("privapp-tree")
    pt.add_argument("--aapt2", type=Path, required=True)
    pt.add_argument("--framework-manifest", type=Path, required=True)
    pt.add_argument("--root", action="append", required=True)
    pt.add_argument("--out", type=Path, required=True)

    sa = sp.add_parser("seapp")
    sa.add_argument("--root", action="append", required=True)
    sa.add_argument("--user")
    sa.add_argument("--seinfo")
    sa.add_argument("--name")
    sa.add_argument("--out", type=Path, required=True)

    inv = sp.add_parser("inventory")
    inv.add_argument("--root", type=Path, required=True)
    inv.add_argument("--out", type=Path, required=True)

    cmp = sp.add_parser("compare-inventory")
    cmp.add_argument("--left", type=Path, required=True)
    cmp.add_argument("--right", type=Path, required=True)
    cmp.add_argument("--out", type=Path, required=True)

    sp.add_parser("selftest")
    args = p.parse_args()
    try:
        if args.cmd == "policy-path":
            return policy_path(args)
        if args.cmd == "contexts":
            return contexts(args)
        if args.cmd == "privapp":
            return privapp(args)
        if args.cmd == "apex-extract":
            return apex_extract(args)
        if args.cmd == "classpath":
            return classpath(args)
        if args.cmd == "privapp-tree":
            return privapp_tree(args)
        if args.cmd == "seapp":
            return seapp(args)
        if args.cmd == "inventory":
            return inventory(args)
        if args.cmd == "compare-inventory":
            return compare_inventory(args)
        if args.cmd == "selftest":
            return selftest()
        p.print_help()
        return 2
    except (D0Error, OSError, UnicodeError, ValueError) as exc:
        print(f"N1I_D0_HOST_HELPER=FAIL reason={exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
