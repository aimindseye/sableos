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
import json
import re
import sys
import xml.etree.ElementTree as ET
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
